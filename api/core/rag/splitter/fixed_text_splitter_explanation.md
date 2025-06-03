---

**RAG用テキストスプリッター (`fixed_text_splitter.py`) コード解説**

このドキュメントは、`api/core/rag/splitter/fixed_text_splitter.py` に定義されているテキストスプリッターの機能と目的について解説します。このスプリッターは、主にRetrieval Augmented Generation (RAG) システムにおいて、大規模なテキストデータを処理しやすい小さなチャンクに分割するために使用されます。

**概要**

このファイルでは、主に2つのクラスが定義されています。

1.  `EnhanceRecursiveCharacterTextSplitter`: テキスト分割の基本的な機能拡張を提供します。
2.  `FixedRecursiveCharacterTextSplitter`: `EnhanceRecursiveCharacterTextSplitter` を継承し、より具体的な分割戦略を実装します。

**1. `EnhanceRecursiveCharacterTextSplitter`**

このクラスは、`core.rag.splitter.text_splitter` モジュール内の `RecursiveCharacterTextSplitter` を継承しています。主な役割は、テキストの長さを計算する方法を定義し、スプリッターのインスタンス生成を補助することです。

*   **主な機能:**
    *   **`from_encoder` クラスメソッド:**
        *   スプリッターのインスタンスを生成するためのファクトリメソッドです。
        *   `embedding_model_instance` (埋め込みモデルのインスタンス) を引数に取り、テキストの長さを計算するエンコーダーを決定します。
        *   内部で `_token_encoder` と `_character_encoder` という2つの長さ計算関数を定義します。
            *   `_token_encoder`: `embedding_model_instance` があればそれを使用し、なければ `GPT2Tokenizer` を使ってテキストのトークン数を計算します。
            *   `_character_encoder`: テキストの文字数を計算します (例: `len(text)`)。
        *   現在の実装では、最終的に親クラスのコンストラクタには `length_function=_character_encoder` が渡されるため、**文字数ベース**でテキストの長さが評価されます。
    *   **継承元:** `RecursiveCharacterTextSplitter` から再帰的な分割の基本ロジックを継承します。

**2. `FixedRecursiveCharacterTextSplitter`**

このクラスは `EnhanceRecursiveCharacterTextSplitter` を継承し、固定セパレータと複数の動的セパレータを用いた、より洗練されたテキスト分割ロジックを提供します。

*   **主なパラメータ:**
    *   `_fixed_separator` (str, デフォルト: `"\n\n"`):
        *   テキストを最初に大まかに分割するための主要な区切り文字です。例えば、段落単位での分割を意図しています。
    *   `_separators` (list[str], デフォルト: `["\n\n", "\n", " ", ""]`):
        *   `_fixed_separator` で分割されたチャンクが、まだ指定された `_chunk_size` を超える場合に、さらに細かく分割するために試行されるセパレータのリストです。リストの順序が優先順位となり、先頭から順に適用が試みられます。
        *   空文字列 `""` は、他のセパレータが見つからない場合に、文字単位での分割を行うことを意味します。
    *   `_chunk_size` (int): チャンクの最大許容サイズ（文字数）。
    *   `_chunk_overlap` (int): 隣接するチャンク間で重複させる文字数。これにより、文脈の連続性を保ちます。

*   **主なメソッド:**
    *   **`__init__(self, fixed_separator: str = "\n\n", separators: Optional[list[str]] = None, **kwargs: Any)`:**
        *   コンストラクタ。`fixed_separator`、`separators`、および親クラスから継承する `_chunk_size`、`_chunk_overlap` などのパラメータを初期化します。
    *   **`split_text(self, text: str) -> list[str]`:**
        1.  入力 `text` を `self._fixed_separator` で初期分割します。
        2.  分割された各チャンクの長さ（文字数）が `self._chunk_size` を超えるか評価します。
        3.  超える場合は `self.recursive_split_text(chunk)` を呼び出して再帰的にさらに分割します。
        4.  超えない場合はそのまま最終的なチャンクのリストに追加します。
        5.  すべての処理済みチャンクからなるリストを返します。
    *   **`recursive_split_text(self, text: str) -> list[str]`:**
        1.  `self._separators` リストから、現在の `text` に含まれる最適なセパレータを選択します。
        2.  選択されたセパレータで `text` を分割します。
        3.  分割された部分を順に処理し、`_chunk_size` を超えないようにマージ（`_merge_splits` メソッドを使用、親クラスから継承）したり、必要であればさらに下位のセパレータで再帰的に分割したりします。
        4.  セパレータが空文字列 `""` の場合は、文字単位でチャンクを形成し、`_chunk_overlap` を考慮しながら `_chunk_size` を超えないように調整します。

**全体的な目的とRAGにおけるユースケース**

このテキストスプリッターは、RAGシステムにおいて以下の重要な役割を担います。

*   **知識ベースのチャンク化:**
    *   大規模なドキュメント（マニュアル、記事、FAQなど）を、検索に適した小さな単位（チャンク）に分割します。各チャンクはベクトル化され、効率的な類似性検索の対象となります。
*   **言語モデルへの入力コンテキスト整形:**
    *   検索によって見つかった関連チャンクを、言語モデルのコンテキストウィンドウサイズに合わせて整形します。`_chunk_size` はこの制限を考慮して設定され、`_chunk_overlap` はチャンク間の文脈の連続性を維持するのに役立ちます。

**利点:**

*   **階層的な分割:** `_fixed_separator` による大まかな分割と、`_separators` による段階的な詳細分割により、テキストの構造をある程度維持しながらチャンク化できます。
*   **文字数ベース:** モデルに依存しない文字数でのチャンクサイズ制御が可能です。
*   **柔軟性:** デフォルトのセパレータに加えて、特定のデータセットに合わせてセパレータをカスタマイズできます。
*   **網羅性:** 最終的に文字単位での分割も可能なため、どのようなテキストでも指定サイズに収めることができます。

**結論**

`FixedRecursiveCharacterTextSplitter` は、RAGシステムのための強力で柔軟なテキスト分割ツールです。ドキュメントを意味のあるチャンクに効率的に分割し、検索精度と下流の言語モデルによる生成品質の向上に貢献します。

---
