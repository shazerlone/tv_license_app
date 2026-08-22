const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('./dist/app.module');
(async()=>{const app=await NestFactory.create(AppModule,{logger:false,rawBody:true});app.setGlobalPrefix('v1');await app.listen(0);const p=app.getHttpServer().address().port;const j=await(await fetch(`http://127.0.0.1:${p}/v1/health`)).json();console.log('integrations=',JSON.stringify(j.integrations,null,0));await app.close();process.exit(0);})().catch(e=>{console.error(e.message);process.exit(1);});
