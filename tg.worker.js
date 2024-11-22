//示例const whitelist = ["/bot123456:"];
//白名单，比如你的机器人token是123456:AAEHxxxxxxxx，那么你可以考虑使用"/bot123456:"作为你的whitelist，这样防止了别人盗用你的反向代理接口
//记得绑定自己的域名，因为自带的.workers.dev应该已经被Fuck了
const whitelist = [""];
const tg_host = "api.telegram.org";

addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request))
})

function validate(path) {
    for (var i = 0; i < whitelist.length; i++) {
        if (path.startsWith(whitelist[i]))
            return true;
    }
    return false;
}

async function handleRequest(request) {
    var u = new URL(request.url);
    u.host = tg_host;
    if (!validate(u.pathname))
        return new Response('Unauthorized', {
            status: 403
        });
    var req = new Request(u, {
        method: request.method,
        headers: request.headers,
        body: request.body
    });
    const result = await fetch(req);
    return result;
}