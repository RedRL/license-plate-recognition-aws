FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies for Python and building OpenALPR
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git \
    python3 python3-venv python3-pip \
    build-essential cmake \
    libtesseract-dev libleptonica-dev \
    liblog4cplus-dev libcurl4-openssl-dev \
    libopencv-dev \
    tesseract-ocr \
    libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Build and install OpenALPR from source
RUN git clone --depth=1 https://github.com/openalpr/openalpr.git /tmp/openalpr && \
    cd /tmp/openalpr/src && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    rm -rf /tmp/openalpr

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt

RUN python3 -m pip install --upgrade pip && \
    pip install --no-cache-dir -r /app/backend/requirements.txt && \
    pip install --no-cache-dir opencv-python==4.10.0.84

COPY backend/ /app/backend/

# OpenALPR default install locations
ENV LOCAL_MODE=true \
    ALPR_COUNTRY=eu \
    OPENALPR_CONFIG_FILE=/etc/openalpr/openalpr.conf \
    UPLOAD_DIR=uploads

EXPOSE 5000

WORKDIR /app/backend

CMD ["python3", "app.py"] 