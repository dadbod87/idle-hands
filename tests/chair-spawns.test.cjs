const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('index.html','utf8');
const slice=(a,b)=>{const i=source.indexOf(a),j=source.indexOf(b,i);assert(i>=0&&j>i,a);return source.slice(i,j);};
function model(){const c={Math,Date};vm.createContext(c);vm.runInContext([
 slice('const ROOM =','/* Deed copy.'),slice('const FIXTURES =','/* ------------------------------------------------------------------'),
 slice('const DECOR =','/* Real things real people'),slice('const SCENERY =','const PROP_LABELS='),
 slice('const officeHash=','function officeFunAt'),slice('function blocked(x, y)','function prettyError'),
 slice('let chairSpawnCache=null;','/* Pins are bought'),
 'this.at=chairAt;this.points=goodChairSpawns();this.offices=OFFICES;this.fixtures=FIXTURES;this.scenery=SCENERY;this.blocked=blocked;'
].join('\n'),c);return c;}
const a=model(),b=model(),points=a.points;assert(points.length>1000,'Many eligible points across the map');
for(const p of points){assert(p.x>=0&&p.y>=130&&p.x+46<=3400&&p.y+54<=1700,'Full chair inside walkable floor');
 for(const o of a.offices)assert(p.x+46<=o.x||p.x>=o.x+o.w||p.y+54<=o.y||p.y>=o.y+o.h,'No chair footprint inside any office');
 for(const f of [...a.fixtures,...a.scenery])assert(p.x+46<=f.x||p.x>=f.x+f.w||p.y+54<=f.y||p.y>=f.y+f.h,'No chair underneath a fixture or scenery');
 assert(!a.blocked(p.x+23,p.y+27)&&!a.blocked(p.x+23,p.y+54),'Chair reachable without a wall at its base');
}
// Flood-fill the actual walkable floor at 10px resolution from the main hall.
const key=(x,y)=>x+','+y,seen=new Set(),queue=[[1480,860]];
for(let i=0;i<queue.length;i++){const [x,y]=queue[i],k=key(x,y);if(seen.has(k)||x<50||x>3350||y<170||y>1660||a.blocked(x,y))continue;seen.add(k);for(const [dx,dy] of [[10,0],[-10,0],[0,10],[0,-10]])queue.push([x+dx,y+dy]);}
for(const p of points)assert(seen.has(key(p.x+23,p.y+27)),'Spawn connected to the main hall');
const bins=Array(9).fill(0),expected=Array(9).fill(0),bin=p=>Math.min(2,Math.floor((p.y+27-130)/1570*3))*3+Math.min(2,Math.floor((p.x+23)/3400*3));
for(const p of points)expected[bin(p)]++;
let minX=Infinity,maxX=0,minY=Infinity,maxY=0;const unique=new Set();
for(let w=4200000;w<4220000;w++){
 const t=w*420000,a1=a.at(t+1200),b1=b.at(t+1200);assert.equal(JSON.stringify(a1),JSON.stringify(b1),'Independent clients share position');
 assert.equal(a.at(t+39000).x,a1.x,'Stable during window');assert.equal(a.at(t+40000),null,'Closes at 40 seconds');assert.equal(a1.endsIn,39000);
 bins[bin(a1)]++;unique.add(key(a1.x,a1.y));minX=Math.min(minX,a1.x);maxX=Math.max(maxX,a1.x);minY=Math.min(minY,a1.y);maxY=Math.max(maxY,a1.y);
}
assert(minX<100&&maxX>3250&&minY<220&&maxY>1550,'Outer map and north/south floor participate');assert(unique.size>points.length*.9,'Not a small recurring cluster');
for(let i=0;i<9;i++){const predicted=expected[i]/points.length*20000;assert(predicted>0);assert(Math.abs(bins[i]-predicted)<predicted*.2,'Distribution follows usable space rather than middle bias');}
console.log('PASS: '+points.length+' safe spawn points; 20,000 windows; independent-client consistency, unchanged 7m/40s timing, office/prop exclusion, full-map coverage and connected walkable floor');
module.exports={model};
