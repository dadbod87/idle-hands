const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const shellQuote=value=>"'"+value.replaceAll("'","'\\''")+"'";
const port=Number(process.env.QA_PORT||8915);
if(!Number.isInteger(port)||port<1024||port>65535)throw Error('QA_PORT must be a local port from 1024 to 65535');
const channel=process.env.QA_BROWSER;
if(channel&&!['chrome','msedge'].includes(channel))throw Error('QA_BROWSER must be chrome or msedge; omit it for bundled Chromium');
module.exports={
 testDir:__dirname,testMatch:'audit.spec.cjs',workers:1,timeout:90000,
 outputDir:path.join(root,'test-results/qa-audit'),
 reporter:[['line'],['html',{outputFolder:path.join(root,'playwright-report/qa'),open:'never'}]],
 use:{baseURL:`http://127.0.0.1:${port}`,headless:true,serviceWorkers:'block',reducedMotion:'reduce',trace:'retain-on-failure',screenshot:'only-on-failure',...(channel?{channel}:{})},
 webServer:{command:`python3 -m http.server ${port} --bind 127.0.0.1 --directory ${shellQuote(root)}`,url:`http://127.0.0.1:${port}`,reuseExistingServer:false},
};
