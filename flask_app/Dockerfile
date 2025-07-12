FROM python:3.14.0b4-alpine3.22

WORKDIR /app

COPY requirements.txt .

RUN apk add --no-cache --virtual .build-deps gcc musl-dev && \
    pip install --no-cache-dir -r requirements.txt && \
    apk del .build-deps

COPY . .

ENV FLASK_APP=main.py

EXPOSE 8080

CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"]
