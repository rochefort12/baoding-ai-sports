package org.dromara.generator;

import cn.hutool.extra.spring.SpringUtil;
import com.baomidou.dynamic.datasource.DynamicRoutingDataSource;
import com.baomidou.mybatisplus.core.incrementer.IdentifierGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.velocity.app.Velocity;
import org.dromara.generator.domain.GenTable;
import org.dromara.generator.domain.GenTableColumn;
import org.dromara.generator.mapper.GenTableColumnMapper;
import org.dromara.generator.mapper.GenTableMapper;
import org.dromara.generator.service.GenTableServiceImpl;
import org.dromara.generator.util.GenUtils;
import org.dromara.generator.util.VelocityInitializer;
import org.dromara.generator.util.VelocityUtils;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.dromara.sports.mcp.McpAccess;
import org.springframework.ai.tool.method.MethodToolCallbackProvider;
import org.dromara.common.mybatis.core.page.TableDataInfo;
import org.springframework.context.support.GenericApplicationContext;

import javax.sql.DataSource;
import java.io.ByteArrayInputStream;
import java.io.StringWriter;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import java.util.zip.ZipInputStream;
import java.nio.file.Path;
import java.nio.file.Files;
import java.net.URLClassLoader;
import java.lang.reflect.Proxy;
import javax.tools.ToolProvider;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/** Checks rendered artifacts and actual multi-table ZIP, not template source strings alone. */
@Tag("local")
class GeneratorPreparationTest {
    @TempDir
    Path compilationDirectory;
    @BeforeAll
    static void initialize() throws Exception {
        var context = new GenericApplicationContext();
        context.registerBean(ObjectMapper.class, () -> new ObjectMapper());
        var dynamic = mock(DynamicRoutingDataSource.class);
        var source = mock(DataSource.class);
        var connection = mock(Connection.class);
        var metadata = mock(DatabaseMetaData.class);
        when(dynamic.getDataSource("master")).thenReturn(source);
        when(source.getConnection()).thenReturn(connection);
        when(connection.getMetaData()).thenReturn(metadata);
        when(metadata.getDatabaseProductName()).thenReturn("PostgreSQL");
        context.registerBean(DynamicRoutingDataSource.class, () -> dynamic);
        var ids = new AtomicLong(10000);
        context.registerBean(IdentifierGenerator.class, () -> entity -> ids.incrementAndGet());
        context.refresh();
        new SpringUtil().postProcessBeanFactory(context.getBeanFactory());
        VelocityInitializer.initVelocity();
    }

    private GenTable table(String name, boolean mcp, String category) {
        GenTable table = new GenTable();
        table.setTableName("asp_" + name);
        table.setDataName("master");
        table.setClassName(Character.toUpperCase(name.charAt(0)) + name.substring(1));
        table.setModuleName("sports");
        table.setBusinessName(name);
        table.setPackageName("org.dromara.sports");
        table.setFunctionName("结构测试");
        table.setFunctionAuthor("AISports");
        table.setTplCategory(category);
        table.setOptions("{\"mcpEnabled\":" + mcp + ",\"treeCode\":\"id\",\"treeParentCode\":\"parent_id\",\"treeName\":\"name\"}");
        var id = new GenTableColumn();
        id.setColumnName("id"); id.setJavaField("id"); id.setJavaType("Long"); id.setIsPk("1");
        id.setColumnComment("主键"); id.setHtmlType("input"); id.setIsList("1");
        table.setColumns(List.of(id)); table.setPkColumn(id);
        table.setMenuIds(List.of(1L,2L,3L,4L,5L,6L));
        return table;
    }

    private String render(String template, GenTable table) {
        var output = new StringWriter();
        Velocity.getTemplate(template, "UTF-8").merge(VelocityUtils.prepareContext(table), output);
        return output.toString();
    }

    @Test
    void optInReadToolsHavePermissionAndPageBounds() {
        String enabled = render("vm/java/controller.java.vm", table("sample", true, "crud"));
        assertTrue(enabled.contains("sports_sample_get"));
        assertTrue(enabled.contains("sports_sample_list"));
        assertTrue(enabled.contains("McpAccess.requirePermission(\"sports:sample:list\")"));
        assertTrue(enabled.contains("pageSize > 100"));
        assertFalse(enabled.contains("@Tool(name = \"sports_sample_add\""));
        assertFalse(render("vm/java/controller.java.vm", table("sample", false, "crud")).contains("@Tool("));
        assertFalse(render("vm/java/controller.java.vm", table("sample", true, "tree")).contains("sports_sample_list"));
        assertFalse(enabled.contains("${"));
    }

    @Test
    void pagesUseGlobalStylesAndDocumentTheirIntegration() {
        for (String template : List.of("vm/vue/index.vue.vm", "vm/vue/index-tree.vue.vm")) {
            String page = render(template, table("sample", false, template.contains("tree") ? "tree" : "crud"));
            assertTrue(page.contains("generated-crud"));
            assertFalse(page.contains("style=\""));
            assertFalse(page.contains("<style"));
        }
        assertTrue(render("vm/docs/module.md.vm", table("sample", true, "crud")).contains("sports:mcp:invoke"));
        assertTrue(render("vm/docs/module.md.vm", table("sample", true, "crud")).contains("## 集成与审查"));
    }

    @Test
    void multiTableZipContainsOneSharedStyleAndBothDocuments() throws Exception {
        var mapper = mock(GenTableMapper.class);
        when(mapper.selectGenTableById(1L)).thenReturn(table("alpha", true, "crud"));
        when(mapper.selectGenTableById(2L)).thenReturn(table("beta", false, "crud"));
        var service = new GenTableServiceImpl(mapper, mock(GenTableColumnMapper.class));
        byte[] zip = service.downloadCode(new String[] {"1", "2"});
        var paths = new ArrayList<String>();
        try (var input = new ZipInputStream(new ByteArrayInputStream(zip))) {
            for (var entry = input.getNextEntry(); entry != null; entry = input.getNextEntry()) {
                paths.add(entry.getName());
                assertTrue(input.readAllBytes().length > 0);
            }
        }
        assertEquals(1, paths.stream().filter(path -> path.endsWith("generated-crud.scss")).count());
        assertTrue(paths.containsAll(List.of("docs/generated/sports/alpha.md", "docs/generated/sports/beta.md")));
        assertEquals(paths.size(), paths.stream().distinct().count());
    }

    @Test
    void postgresNumericRetainsDecimalPrecision() {
        GenTableColumn column = new GenTableColumn();
        column.setColumnName("amount"); column.setColumnType("NUMERIC(18,2)");
        GenUtils.initColumnField(column, table("sample", false, "crud"));
        assertEquals("BigDecimal", column.getJavaType());
    }

    @Test
    void generatedControllerCompilesAndToolCallbackEnforcesBounds() throws Exception {
        String controller = render("vm/java/controller.java.vm", table("sample", true, "crud"));
        Path controllerFile = compilationDirectory.resolve("SampleController.java");
        Files.writeString(controllerFile, controller);
        Path vo = compilationDirectory.resolve("SampleVo.java");
        Files.writeString(vo, "package org.dromara.sports.domain.vo; public class SampleVo {}");
        Path bo = compilationDirectory.resolve("SampleBo.java");
        Files.writeString(bo, "package org.dromara.sports.domain.bo; public class SampleBo {}");
        Path service = compilationDirectory.resolve("ISampleService.java");
        Files.writeString(service, """
            package org.dromara.sports.service;
            import java.util.*;
            import org.dromara.sports.domain.vo.SampleVo;
            import org.dromara.sports.domain.bo.SampleBo;
            import org.dromara.common.mybatis.core.page.*;
            public interface ISampleService {
                TableDataInfo<SampleVo> queryPageList(SampleBo bo, PageQuery page);
                List<SampleVo> queryList(SampleBo bo);
                SampleVo queryById(Long id);
                Boolean insertByBo(SampleBo bo);
                Boolean updateByBo(SampleBo bo);
                Boolean deleteWithValidByIds(Collection<Long> ids, Boolean validate);
            }
            """);
        var compiler = ToolProvider.getSystemJavaCompiler();
        assertNotNull(compiler, "Tests require the JDK, not a JRE");
        try (var files = compiler.getStandardFileManager(null, null, null)) {
            var sources = files.getJavaFileObjects(controllerFile.toFile(), vo.toFile(), bo.toFile(), service.toFile());
            var options = List.of("-classpath", System.getProperty("java.class.path"), "-d", compilationDirectory.toString(),
                "-encoding", "UTF-8", "-parameters", "-processor", "lombok.launch.AnnotationProcessorHider$AnnotationProcessor");
            assertTrue(compiler.getTask(null, files, null, options, null, sources).call(), "Rendered controller must compile");
        }
        try (var loader = new URLClassLoader(new java.net.URL[] {compilationDirectory.toUri().toURL()}, getClass().getClassLoader());
             var access = mockStatic(McpAccess.class)) {
            Class<?> serviceType = loader.loadClass("org.dromara.sports.service.ISampleService");
            var calls = new AtomicLong();
            Object implementation = Proxy.newProxyInstance(loader, new Class<?>[] {serviceType}, (proxy, method, args) -> {
                if (method.getName().equals("queryPageList")) {
                    calls.incrementAndGet();
                    var page = (org.dromara.common.mybatis.core.page.PageQuery) args[1];
                    assertEquals(1, page.getPageNum()); assertEquals(10, page.getPageSize());
                    return new TableDataInfo<>(List.of(), 0);
                }
                return null;
            });
            Object instance = loader.loadClass("org.dromara.sports.controller.SampleController")
                .getConstructor(serviceType).newInstance(implementation);
            var callbacks = MethodToolCallbackProvider.builder().toolObjects(instance).build().getToolCallbacks();
            var list = java.util.Arrays.stream(callbacks).filter(callback -> callback.getToolDefinition().name().endsWith("_list")).findFirst().orElseThrow();
            list.call("{\"pageNum\":1,\"pageSize\":10}");
            assertEquals(1, calls.get());
            access.verify(() -> McpAccess.requirePermission("sports:sample:list"));
            assertThrows(Exception.class, () -> list.call("{\"pageNum\":1,\"pageSize\":101}"));
            assertEquals(1, calls.get(), "Invalid page must not reach the business service");
            assertEquals(2, callbacks.length, "Only read tools are registered");
        }
    }
}
