// In-memory Phoenix/Supabase broadcast relay. Never opens a production socket.
function makeLiveBus(){
 const sockets=[],messages=[];
 return {messages,sockets,connect(ws){
  const peer={ws,topics:new Set()};sockets.push(peer);
  ws.onMessage(data=>{
   const raw=JSON.parse(String(data)),arr=Array.isArray(raw),m=arr?{join_ref:raw[0],ref:raw[1],topic:raw[2],event:raw[3],payload:raw[4]}:raw;
   const send=(p,target=ws)=>target.send(JSON.stringify(arr?[p.join_ref??m.join_ref,p.ref??null,p.topic,p.event,p.payload]:p));
   const reply=response=>send({...m,event:'phx_reply',payload:{status:'ok',response}});
   if(m.event==='phx_join'){peer.topics.add(m.topic);reply({postgres_changes:[]});}
   else if(m.event==='heartbeat')reply({});
   else if(m.event==='broadcast'){
    messages.push(m);
    for(const other of sockets)if(other!==peer&&other.topics.has(m.topic))send({topic:m.topic,event:'broadcast',payload:m.payload,ref:null,join_ref:null},other.ws);
    reply({});
   }else if(m.event==='phx_leave'){peer.topics.delete(m.topic);reply({});}
  });
  ws.onClose(()=>{const i=sockets.indexOf(peer);if(i>=0)sockets.splice(i,1);});
 }};
}
module.exports={makeLiveBus};
