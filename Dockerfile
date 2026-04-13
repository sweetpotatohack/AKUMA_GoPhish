# Minify client side assets (JavaScript)
FROM node:latest AS build-js

RUN npm install gulp gulp-cli -g

RUN apt-get update && apt-get install -y git
WORKDIR /build
RUN git clone https://github.com/gophish/gophish .
RUN npm install --only=dev
RUN gulp


# Build Golang binary
FROM golang:1.22 AS build-golang

WORKDIR /build
COPY --from=build-js /build/ ./

# Stripping X-Gophish 
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go
RUN sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go

# Stripping X-Gophish-Signature
RUN sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go

# Changing servername
RUN sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go

# Changing rid value
RUN sed -i 's/const RecipientParameter = "rid"/const RecipientParameter = "id"/g' models/campaign.go

# Copying in custom 404 handler
COPY ./files/phish.go ./controllers/phish.go

# Per-recipient QR codes in email templates ({{.QRCode}} — same URL as {{.URL}}, PNG inline base64)
COPY ./files/gophish-patches/models/template_context.go ./models/template_context.go
RUN go get github.com/skip2/go-qrcode@v0.0.0-20200617195104-da1b6568686e && go mod tidy

RUN go mod download && go build -v -o gophish .


# Runtime container
FROM debian:stable

RUN useradd -m -d /opt/gophish -s /bin/bash app

RUN apt-get update && \
	apt-get install --no-install-recommends -y jq libcap2-bin && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/gophish
COPY --from=build-golang /build/ ./
COPY --from=build-js /build/static/js/dist/ ./static/js/dist/
COPY --from=build-js /build/static/css/dist/ ./static/css/dist/
COPY --from=build-golang /build/config.json ./
COPY ./files/404.html ./templates/
RUN chown app. config.json

RUN setcap 'cap_net_bind_service=+ep' /opt/gophish/gophish

USER app
RUN sed -i 's/127.0.0.1/0.0.0.0/g' config.json && \
    mkdir -p data

RUN touch config.json.tmp

EXPOSE 3333 80 443

CMD ["./docker/run.sh"]
