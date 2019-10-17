# docker-resty-php7
Full stack PHP7-FPM extensions w/ OpenResty

## Example

### Docker

```
docker run -d -p 8888:80 chet/docker-resty-php7
```

### Docker compose

Default in docker-compose.yml use custom build image.
If you want to use image instead of build change docker-comoise.yml file

from

```
build: .
```

to

```
image: chet/docker-resty-php7
```

Then start container

```
docker-compose up -d
```

[http://127.0.0.1:8888/](http://127.0.0.1:8888/)

