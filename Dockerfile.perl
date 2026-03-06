FROM perl:5.38-bullseye

VOLUME tmp /root/.cpanm/work

RUN apt-get update && apt-get install -y \
    perl \
    build-essential \
    # libmysqlclient-dev \
    libmariadb-dev-compat \
    libdbi-perl \
    cpanminus \
    && rm -rf /var/lib/apt/lists/*

# CPANモジュールをインストール
RUN cpanm --notest \
  RDF::Trine@1.019 \
  DBI@1.647 \
  DBD::mysql@4.052 \
  JSON@4.10

WORKDIR /usr/src/app

COPY bin bin

CMD ["perl", "-v"]