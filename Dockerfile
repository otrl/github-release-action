FROM alpine:3.10
LABEL "maintainer"="On Track Retail - Development Team"

COPY entrypoint.sh /entrypoint.sh

RUN apk update && apk add bash git curl

ENTRYPOINT ["/entrypoint.sh"]
