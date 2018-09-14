const redis = require('redis'),
    config = require('config'),
    http = require('http').createServer((req, res) => {res.writeHead(200);res.end('Ok')}),
    io = require('socket.io')(http)
;

let redisClient = redis.createClient(config.get('redis'));

redisClient.on('reconnecting', (e) => console.error("reconnecting... attempt " + e.attempt));
redisClient.on('error', (e) => {
    if (e.errno === 'ECONNREFUSED') {
        console.error(`Connection failed on ${e.address}:${e.port}`)
    } else {
        console.error(e)
    }
});

config.get('services').forEach(e => {
    redisClient.psubscribe(e.channel);
});

config.get('services').forEach((service) => {
    io
        .of(`/${service.service}`)
        .on('connection', function (socket) {
           console.info(`connection on ${service.service} channel : ${socket.id}`);
           redisClient.on("pmessage", function (pattern, channel, message) {
               const service = config.get('services').find(e => e.channel === pattern);

               // if  the reddis event is not for this service, we skip it
               if(!pattern.includes(`${service.entity}`)) {
                   return;
               }

               const msg = JSON.parse(message);

               //message are send in volatile mode, so no client will be locked waiting for others
               socket.volatile.emit(channel, msg);
           });
   })
});

const port = config.get('application.port');
http.listen(port, () => console.log('app listening on ' + port));
