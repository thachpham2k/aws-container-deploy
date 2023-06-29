# Deploy to EC2

Result

```shell
$ curl `curl "http://169.254.169.254/latest/meta-data/public-ipv4"`:80
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    13  100    13    0     0   4575      0 --:--:-- --:--:-- --:--:--  6500
<!DOCTYPE HTML>
<html>
<head>
  <title>Getting Started: Serving Web Content</title>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
</head>
<body>
        <p>Hello from Docker!</p>
</body>
```

Docker ps

```shell
$ docker ps
CONTAINER ID   IMAGE                    COMMAND                  CREATED         STATUS         PORTS                               NAMES
d73d3fb5a7cf   nginx                    "/docker-entrypoint.…"   4 seconds ago   Up 2 seconds   0.0.0.0:80->80/tcp, :::80->80/tcp   nginx
3d4b1023fb92   docker-compose_backend   "java -cp app:app/li…"   5 seconds ago   Up 3 seconds   8080/tcp                            backend
75c476a2caee   postgres                 "docker-entrypoint.s…"   5 seconds ago   Up 3 seconds   5432/tcp                            database
```

```shell
$ docker-compose up -d
Recreating docker-compose_database_1 ... done
Recreating docker-compose_backend_1  ... done
Recreating docker-compose_web_1      ... done
```

```shell
$ docker-compose down
Stopping nginx    ... done
Stopping backend  ... done
Stopping database ... done
Removing nginx    ... done
Removing backend  ... done
Removing database ... done
Removing network docker-compose_backend-net
```
