import rdflib
import argparse

# nando.ttl => nando.obo を生成する前に、日本語と英語のデータに分ける必要がある。
# Turtleファイルを読み込む
parser = argparse.ArgumentParser(description='Convert turtle to flatten turtle file.')
parser.add_argument('-i', help='Path to the input turtle file')
parser.add_argument('-o', help='Path to the output turtle file')
parser.add_argument('-ja_tsv', help='Path to the output only japanese tsv file')
args = parser.parse_args()

# Turtleファイルを読み込む
g = rdflib.Graph()
g.parse(args.i, format="turtle")

# 出力用のファイルを開く
with open(args.o, "w") as f:
  for subj, pred, obj in g:
    if isinstance(obj, rdflib.Literal):
      # リテラルの言語タグやデータ型を処理
      literal_str = f'"{obj}"'
      if obj.language:
          literal_str += f"@{obj.language}"  # 言語タグを追加
      elif obj.datatype:
          literal_str += f"^^<{obj.datatype}>"  # データ型を追加
      f.write(f"<{subj}> <{pred}> {literal_str} .\n")
    else:
      # オブジェクトがリテラルでない場合（URIなど）
      f.write(f"<{subj}> <{pred}> <{obj}> .\n")

# nando_ja.tsv のファイルパスが引数で指定されていれば生成する
if args.ja_tsv is not None:
  with open(args.ja_tsv, "w") as f:
    f.write(f"id\ttype\tval\n")
    for subj, pred, obj in g:
      if isinstance(obj, rdflib.Literal):
        if obj.language == "ja" and "obsolete" not in obj:
          pred_value = ""
          if pred.endswith("rdf-schema#label"):
              pred_value =  "label_ja"
          elif pred.endswith("core#altLabel"):
              pred_value =  "synonym_ja"
          elif pred.endswith("terms/description"):
              pred_value =  "description_ja"
          # predicate が対象のものであれば
          if pred_value != "":
              f.write(f"{subj.split('/')[-1].replace('_', ':')}\t{pred_value}\t{obj}\n")