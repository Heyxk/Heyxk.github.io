#docker run --rm -it --user 1030:1030 -v $PWD:/src klakegg/hugo:0.112.4-ext-alpine $@
cmd="hugo $@"
docker run --rm -it --user 1030:1030 -v $PWD:/home/app betterweb/hugo:extended-0.121.1-20-1 -c "$cmd"
