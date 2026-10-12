import java.io.BufferedReader;
import java.io.InputStreamReader;
import cn.hutool.crypto.digest.BCrypt;
/** Test-only helper: credential arrives on private stdin, never in arguments or source. Output is captured by the test runner. */
public class TestPasswordHasher {
 public static void main(String[] args)throws Exception{String input=new BufferedReader(new InputStreamReader(System.in)).readLine();if(input==null||input.length()<16)throw new IllegalArgumentException("Invalid fixture credential");System.out.print(BCrypt.hashpw(input,BCrypt.gensalt()));}
}
