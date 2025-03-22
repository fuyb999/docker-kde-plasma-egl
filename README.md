# docker-kde-plasma-egl

### coturn
```shell
sudo docker run --name coturn --restart=always -d -p 3478:3478 -p 3478:3478/udp -p 65500-65535:65500-65535 \
    -p 65500-65535:65500-65535/udp ghcr.nju.edu.cn/coturn/coturn -n --listening-ip="0.0.0.0" --listening-ip="::" \
    --external-ip="192.168.2.50" --min-port=65500 --max-port=65535 --use-auth-secret \
    --static-auth-secret=n0TaRealCoTURNAuthSecretThatIsSixtyFourLengthsLongPlaceholdPlace
```