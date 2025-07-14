ARG NGINX_VERSION=1.29.0

FROM nginx:$NGINX_VERSION-alpine AS build
# add required dependencies
RUN apk add --no-cache --virtual .build-deps \
   linux-headers \
   build-base \
   git \
   pcre2-dev \
   openssl-dev \
   zlib-dev \
   cmake
RUN apk add --no-cache --virtual .brotli-dev \
   brotli-dev
# nginx
RUN wget https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
RUN tar -xzf nginx-$NGINX_VERSION.tar.gz && rm nginx-$NGINX_VERSION.tar.gz
RUN mv nginx-$NGINX_VERSION nginx
# download ngx_brotli
RUN git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
RUN cd ngx_brotli && git checkout a71f9312c2deb28875acc7bacfdd5695a111aa53
# build ngx_brotli
WORKDIR /ngx_brotli/deps/brotli/out
ENV CFLAGS="-march=native -mtune=native -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections"
ENV LDFLAGS="-Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections"
RUN cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CFLAGS" -DCMAKE_INSTALL_PREFIX=./installed ..
RUN cmake --build . --config Release --target brotlienc
# build nginx
WORKDIR /nginx
RUN export NGINX_ARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') && eval ./configure --add-module=/ngx_brotli $NGINX_ARGS
RUN make && make install DESTDIR=/app

FROM nginx:$NGINX_VERSION-alpine
COPY --from=build /app .