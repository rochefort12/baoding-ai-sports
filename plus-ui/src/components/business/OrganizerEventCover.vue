<template><div class="organizer-cover"><img :src="url || '/images/sports/badminton-hero-v1.webp'" alt="赛事封面" loading="lazy"/><span v-if="!fileId">羽毛球</span></div></template>
<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue';
import request from '@/utils/request';
const props=defineProps<{fileId?:string|null}>(),url=ref('');let stamp=0;
watch(()=>props.fileId,async(id)=>{const sequence=++stamp;if(url.value)URL.revokeObjectURL(url.value);url.value='';if(!id)return;try{const blob=(await request({url:`/sports/b/media/${id}`,responseType:'blob'})) as unknown as Blob;if(sequence===stamp)url.value=URL.createObjectURL(blob);}catch{/* The private file remains attached; the fallback is visual only. */}},{immediate:true});onBeforeUnmount(()=>{++stamp;if(url.value)URL.revokeObjectURL(url.value);});
</script>
<style scoped>.organizer-cover{position:relative;overflow:hidden;border-radius:18px;background:var(--s-paper);height:100%;min-height:142px;}img{width:100%;height:100%;object-fit:cover;position:absolute;inset:0;}span{position:absolute;left:12px;bottom:12px;background:#ffffffd9;color:#202321;padding:5px 10px;border-radius:20px;font-size:10px;font-weight:600;backdrop-filter:blur(8px);}@media(max-width:600px){.organizer-cover{min-height:180px;aspect-ratio:16/9;}}</style>
