# 🚢 MTProxy Docker Image

[![](https://img.shields.io/docker/pulls/mtproxy/mtproxy.svg?style=flat-square)](https://hub.docker.com/r/mtproxy/mtproxy)
[![](https://img.shields.io/microbadger/image-size/mtproxy%2Fmtproxy.svg?style=flat-square)](https://microbadger.com/images/mtproxy/mtproxy)

The Telegram Messenger [MTProto proxy](https://github.com/TelegramMessenger/MTProxy) is a zero-configuration container that automatically sets up a proxy server that speaks Telegram's native MTProto.

ℹ️ This image is an unofficial fork of [telegrammessenger/proxy](https://hub.docker.com/r/telegrammessenger/proxy) which left unmaintained for a while.

##  🚀 Quick Reference

First pull the docker image from docker-hub: `docker pull mtproxy/mtproxy`

### 🧪 Testing Proxy

To start a testing container use:

```bash
docker run -it --rm -p443:443 mtproxy/mtproxy
```

The container's log output will contain the links to paste into the Telegram app:

```
[+] No secret passed. Will generate 1 random ones.
[*] Final configuration:[*]   Secret 1: ...
[*]   tg:// link for secret 1 auto configuration: tg://proxy?server=...6&port=443&secret=...
[*]   t.me link for secret 1: https://t.me/proxy?server=...&port=443&secret=...
[*]   Tag: no tag[*]   External IP: ...
[*]   Make sure to fix the links in case you run the proxy on a different port.
```

### ⛅ Daemon

To start the proxy as a *permanent* daemon which starts after server restart too:

```bash
docker run -d -p443:443 --name=mtproxy --restart=always -v mtproxy:/data mtproxy/mtproxy
````

Then obtain links for telegram app by reading container's logs with `docker logs -f mtproxy`.

### ℹ️ Tips

- The secret will persist across container upgrades in a volume. It is a mandatory configuration parameter. If not provided, it will be generated automatically at container start. 

- You may forward any other port to the container's `443` by changing left side port.

- Be sure to fix the automatic configuration links if you do so.

Please note that the proxy gets the Telegram core IP addresses at the start of the container. We try to keep the changes to a minimum, but you should restart the container about once a day, just in case.

## 🔖 Registering Your Proxy

Once your MTProxy server is up and running go to [@MTProxybot](https://t.me/mtproxybot) and register your proxy with Telegram to gain access to usage statistics and monetization. Then set the `TAG` environment variable.

## ⚙️ Custom Configuration

Several options are configurable using environment variables.

### `SECRET`/`SECRET_COUNT`

If you need to specify a custom secret (say, if you are deploying multiple proxies with DNS load-balancing), you may pass the `SECRET` environment variable as 16 bytes in lower-case hexidecimals: `docker run ... -e SECRET=00baadf00d15abad1deaa51sbaadcafe mtproxy/mtproxy`

The proxy may be configured to accept up to 16 different secrets. You may specify them explicitly as comma-separated hex strings in the `SECRET` environment variable, or you may let the container generate the secrets automatically using the `SECRET_COUNT` variable to limit the number of generated secrets.

**💡Example:** Manualy specify different secrets: `docker run ... -e SECRET=secret1,secret2 mtproxy/mtproxy` 

**💡Example:** Set secret count: `docker run ... -e SECRET_COUNT=4 mtproxy/mtproxy`

### `TAG`

A custom advertisement tag may be provided using the `TAG` environment variable:

**💡Example:** Setting Tag: `docker run ... -e TAG=3f40462915a3e6026a4d790127b95ded mtproxy/mtproxy`

Please note that the tag is not persistent. You'll have to provide it as an environment variable every time you run an MTProto proxy container.

### `WORKERS`

A single worker process is expected to handle tens of thousands of clients on a modern CPU. For best performance we artificially limit the proxy to `60000` connections per core and run **one** workers by default. If you have many clients, be sure to adjust the `WORKERS` variable.

**💡Example:** Setting number of workers to 16: `docker run ... -e WORKERS=16 mtproxy/mtproxy`

### Other Environment Variables

- `DEBUG`: Set to `true` to enable init script debugging.
- `SECRET_FILE`: Where to store generated secret.Defaults to `/data/secret`
- `PROXY_SECRET_FILE`: Optained from telegram servers for communication during init. Defaults to `/data/proxy.secret`
- `PROXY_CONFIG_FILE`: Telegram core IP addresses obtained from telegram during init. Defaults to `/data/proxy.conf`
- `IP`: Server external IP. If not provided, will be automatically detected
- `INTERNAL_IP`: Server internal IP for NAT. If not provided, will be automatically detected,
- `PORT`: Listening port. Defaults to `443`
- `INTERNAL_PORT`: Monitoring port. Defaults to `2398`
- `ARGS`: Additional custom args to be passed to `mtproto-proxy` binary

## 📈 Monitoring

The MTProto proxy server exports internal statistics as tab-separated values over the http://localhost:2398/stats endpoint. Please note that this endpoint is available only from localhost: depending on your configuration, you may need to collect the statistics with `docker exec mtproto-proxy curl http://localhost:2398/stats`.

- `ready_targets`: number of Telegram core servers the proxy will try to connect to.
- `active_targets`: number of Telegram core servers the proxy is actually connected to. Should be equal to ready_targets.
- `total_special_connections`: number of inbound client connections
- `total_max_special_connections`: the upper limit on inbound connections. Is equal to `60000` multiplied by worker count.

## 🔧 Troubleshooting

MTProto Proxy may fail to operate properly in certain conditions. There are two major problem categories: the client might not be able to connect to your proxy server (client applications will hang in "connecting" state), or your proxy server is unable to connect to the core Telegram servers (application hangs in "updating" state).

"Connecting" problems are usually caused by a misconfigured firewall, a Docker port forwarding problem, a state censorship issue, or a combination of the above.

If clients hang in an "updating" state, be sure to check the following:

1. Firewalls and/or DPI checkpoints between your proxy server and the core Telegram servers may not allow traffic to pass. Check your local firewall first.
2. Your proxy server's system time should be within five seconds of UTC. You should be running a time synchronization daemon to keep these issues to a minimum.
3. The MTProto Proxy must know about its globally routable external IP address if it's behind NAT. The container tries to detect the external IP address automatically, but this may fail if you have extracted the binary out of the container. Use `mtproto-proxy --nat-info` command line switch to configure the proxy server.
