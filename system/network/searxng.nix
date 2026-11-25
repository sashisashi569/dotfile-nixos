{ pkgs, ... }:

{
  # ローカルホスト専用の SearXNG。MCP (nixpkgs の mcp-searxng) から
  # http://127.0.0.1:8080 の JSON API 経由で検索する。
  services.searx = {
    enable = true;

    # 上流 SearXNG (この nixpkgs の rev) の DDG 周りの不具合を修正する。
    #
    # DDG エンジンはブラウザ用ヘッダ (Sec-Fetch-*) を送る一方 Accept を
    # 設定しないため httpx (以前は curl_cffi) 既定の `Accept: */*` になる。
    # WAF はこの組み合わせを拒否し 406 を返す (curl や Accept を明示した
    # リクエストは 200) ため、ブラウザ相当の Accept を追加する。
    #
    # 以前は httpx-socks 0.13.1 が受け付けない `loop=get_loop()` を
    # searx/network/client.py から除去していたが、上流が curl_cffi ベースに
    # 書き換えて該当行自体が消えたためパッチを削除した。
    package = pkgs.searxng.overridePythonAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace searx/engines/duckduckgo.py \
          --replace-fail \
            'headers["Sec-Fetch-User"] = "?1"' \
            'headers["Sec-Fetch-User"] = "?1"; headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"'
      '';
    });

    settings = {
      general.instance_name = "searxng-local";

      server = {
        bind_address = "127.0.0.1";
        port = 8080;
        # localhost 専用のため外部からの bot 判定を無効化 (MCP の問い合わせが
        # limiter に弾かれないようにする)。
        limiter = false;
        # セッション/CSRF 署名用。上流の既定値 "ultrasecretkey" のままだと
        # 起動を拒否されるため変更する。外部非公開なので固定値で問題ない。
        secret_key = "searxng-local-only-not-a-secret";
      };

      search = {
        safe_search = 0;
        # mcp-searxng は JSON API を使うため json を許可する。
        formats = [
          "html"
          "json"
        ];
      };

      # 全エンジンを有効化して実測し、3クエリすべて失敗、または
      # 平均応答が 10 秒を超えたエンジンを無効化している。
      engines = [
        {
          name = "azure";
          disabled = true;
        }
        {
          name = "baidu";
          disabled = true;
        }
        {
          name = "baidu kaifa";
          disabled = true;
        }
        {
          name = "bitbucket";
          disabled = true;
        }
        {
          name = "brave";
          disabled = true;
        }
        {
          name = "brave.images";
          disabled = true;
        }
        {
          name = "brave.videos";
          disabled = true;
        }
        {
          name = "chinaso news";
          disabled = true;
        }
        {
          name = "docker hub";
          disabled = true;
        }
        {
          name = "duckduckgo news";
          disabled = true;
        }
        {
          name = "free software directory";
          disabled = true;
        }
        {
          name = "google cse images";
          disabled = true;
        }
        {
          name = "google play apps";
          disabled = true;
        }
        {
          name = "hoogle";
          disabled = true;
        }
        {
          name = "kukei";
          disabled = true;
        }
        {
          name = "mdn";
          disabled = true;
        }
        {
          name = "minecraft wiki";
          disabled = true;
        }
        {
          name = "mojeek";
          disabled = true;
        }
        {
          name = "mojeek images";
          disabled = true;
        }
        {
          name = "mojeek news";
          disabled = true;
        }
        {
          name = "naver news";
          disabled = true;
        }
        {
          name = "nixos wiki";
          disabled = true;
        }
        {
          name = "quark";
          disabled = true;
        }
        {
          name = "qwant";
          disabled = true;
        }
        {
          name = "qwant images";
          disabled = true;
        }
        {
          name = "qwant videos";
          disabled = true;
        }
        {
          name = "rawweb";
          disabled = true;
        }
        {
          name = "rubygems";
          disabled = true;
        }
        {
          name = "searchmysite";
          disabled = true;
        }
        {
          name = "startpage";
          disabled = true;
        }
        {
          name = "startpage images";
          disabled = true;
        }
        {
          name = "startpage news";
          disabled = true;
        }
        {
          name = "unobtanium";
          disabled = true;
        }
        {
          name = "wikidata";
          disabled = true;
        }
        {
          name = "wikinews";
          disabled = true;
        }
        {
          name = "wikipedia";
          disabled = true;
        }
        {
          name = "wikisource";
          disabled = true;
        }
        {
          name = "wikispecies";
          disabled = true;
        }
        {
          name = "wikiversity";
          disabled = true;
        }
        {
          name = "wikivoyage";
          disabled = true;
        }
        {
          name = "wiktionary";
          disabled = true;
        }
        {
          name = "yandex api";
          disabled = true;
        }
      ];
    };
  };
}
