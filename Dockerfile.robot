FROM obolibrary/robot:v1.9.6

# 必要なパッケージをインストールするための更新と nkf xsltproc raptor2-utils のインストール
RUN apt-get update && \
    apt-get install -y nkf xsltproc raptor2-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# コンテナの動作を確認するためのサンプルコマンド（オプション）
CMD ["robot", "--help"]