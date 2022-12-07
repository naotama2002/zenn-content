---
title: "ハンズオン2"
free: false
---

# リストに追加する

リストが表示できたので、次はリストを追加できるようにしてみましょう。
リストの追加は、右下のボタンを利用して実装することにします。

まずはリストに追加する関数 _addTodo()を実装しましょう。配列に文字列を追加したときにリストも変更されるように、 setState() を使います。add() は配列に引数の値を追加するメゾットです。
なお _incrementCounter() と _counter は使わないので削除してかまいません。

```dart diff
  class _MyHomePageState extends State<MyHomePage> {
  
    final List<String> _todoItems = [
      // 略
    ];

-   void _incrementCounter() {
-     setState(() {
-     });
-   }
  
+   void _addTodo(String title) {
+     setState(() {
+       _todoItems.add(title);
+     });
+   }
```

そして、追加した _addTodo() がボタンを押したときに呼び出されるように指定しましょう。
押されたときに呼び出すのは onPressed で指定します。floatingActionButton を以下のように変更しましょう。

```dart diff
  floatingActionButton: FloatingActionButton(
-   onPressed: _incrementCounter,
+   onPressed: () => _addTodo("追加したTODO"),
-   tooltip: 'Increment',
+   tooltip: 'Add Todo',
    child: const Icon(Icons.add),
  ),
```

▶RUNを押して、右下の＋ボタンを押してみましょう！

![](https://storage.googleapis.com/zenn-user-upload/1cf755b06618-20221206.png)

↓

![](https://storage.googleapis.com/zenn-user-upload/c8676d14f408-20221206.png)

リストに追加は出来ますが、決まった文字ではなく自分で入力した文字を追加できるようにしたいですよね。「今日戻ったらNTTデータSBCについてもう少し調べてみるか」とかね。

ということで次は TODO を入力する新規作成ページを実装していきます。
まずは右下のボタンを押したら新規作成ページに遷移するように実装しましょう。

# 新規作成ページ

まずは新しく新規作成ページを作ります。
中身はあとで変更するのでとりあえず以下の内容を追加してください。

```dart diff
+ class CreatePage extends StatefulWidget {
+   const CreatePage({Key? key}) : super(key: key);
+ 
+   @override
+   State<CreatePage> createState() => _CreatePageState();
+ }
+ 
+ class _CreatePageState extends State<CreatePage> {
+ 
+   @override
+   Widget build(BuildContext context) {
+     return Scaffold(
+       appBar: AppBar(
+         title: const Text("Create TODO"),
+       ),
+       body: const Center(
+         child: Text("新規作成ページ"),
+       ),
+     );
+   }
+ }
```

次はこの画面に遷移できるように実装しましょう。

# 画面遷移

今回は my_home_page の右下の floatingActionButtion を押したときに遷移をしたいので、 floatingActionButtion の onPressed に create_page へ遷移する処理を記述します。
ページへ遷移するときは、Navigator.of(context).push() を呼び出します。

```dart diff
  floatingActionButton: FloatingActionButton(
-   onPressed: () => _addTodo("追加したTODO"),
+   onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreatePage())),
    tooltip: 'Add Todo',
    child: const Icon(Icons.add),
  ),
```

また、create_page から my_home_page に戻るボタンも作りましょう。
前のページに戻るには、Navigator.pop(context) を呼び出します。

```dart diff
- body: const Center(
-   child: Text("新規作成ページ"),
+ body: Center(
+   child: Column(
+     mainAxisSize: MainAxisSize.min,
+     children: [
+       const Text("新規作成ページ"),
+       ElevatedButton(
+         child: const Text("Back"),
+         onPressed: () => Navigator.pop(context),
+       ),
+     ]
+   ),
  ),
```

my_home_page で右下のボタンを押すと create_page に遷移し、create_page でボタンを押すと my_home_page に戻ります。

![](https://storage.googleapis.com/zenn-user-upload/c6b18e44b696-20221206.png)

# 入力フォームの作成

次は TODO を入力するフォームを作成しましょう。
create_page に、入力した文字を入れる変数 _title を追加します。

```dart diff
  class _CreatePageState extends State<CreatePage> {
  
+   String _title = "";
```

そしてテキストフォームの Widget である TextField を追加します。

```dart diff
  body: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
-       const Text("新規作成ページ"),
+       const Text("TODOを入力してください"),
+       TextField(
+         onChanged: (String text) => _title = text,
+       ),
        ElevatedButton(
          child: const Text("Back"),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  ),
```

これでTODO入力フォームが作成できました。

![](https://storage.googleapis.com/zenn-user-upload/b663d5ed3568-20221206.png)

次はこの入力したテキストを TODO リストへ追加できるようにしていきましょう。

# my_home_page に入力したテキストを渡す

create_page で入力したテキストを my_home_page に渡すように実装してみましょう。
前の画面へ戻るときに値を渡したいときは、Navigator.pop() の第二引数に渡したい値を指定します。

```dart diff
  body: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("TODOを入力してください"),
        TextField(
          onChanged: (String text) => _title = text,
        ),
        ElevatedButton(
-         child: const Text("Back"),
+         child: const Text("Add"),
-         onPressed: () => Navigator.pop(context),
+         onPressed: () => Navigator.pop(context, _title),
        ),
      ],
    ),
  ),
```

そして前の画面(my_home_page)では以下のようにすることで、値を受け取ることができます。

```dart diff
  floatingActionButton: FloatingActionButton(
-   onPressed: () =>  Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreatePage())),
+   onPressed: () async {
+     final String title = await Navigator.of(context)
+       .push(MaterialPageRoute(builder: (context) => CreatePage()));
+   },
    tooltip: 'Add Todo',
    child: const Icon(Icons.add),
  ),
```

これで値を受け取ることができました。

:::message
### async・await
async・await は非同期処理の構文です。少し難しいですがすごく簡単に説明すると、普通の関数では上から一行ずつ実行するところを、async を利用した関数ではいくつもの処理を並行して実行します。そして async を利用した関数内で await があると、その関数は処理を一時停止して await のついた処理を待ちます。

つまり上の処理は、my_home_page から create_page に遷移し、値が返ってくるのを待っているということです。
:::

# 受け取ったテキストを TODO リストに追加

リストに追加するのは、テキストを受け取った後に _addTodo() を呼び出すだけです。

```dart diff
  floatingActionButton: FloatingActionButton(
    onPressed: () async {
      final String title = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => CreatePage()));
+     _addTodo(title);
    },
    tooltip: 'Add Todo',
    child: const Icon(Icons.add),
  ),
```

これで、

1. my_home_page から create_page に遷移。
2. create_page で TODO を入力。
3. ボタンを押すと my_home_page に戻る。
4. 入力された TODO をリストに追加する。

という一連の流れが実装できました。

![](https://storage.googleapis.com/zenn-user-upload/151996458683-20221206.png)

↓ Add押す ↓

![](https://storage.googleapis.com/zenn-user-upload/b43750f51880-20221206.png)

しかしこのままだと何も入力しないで戻ったときや、左上をタップして戻ったときなどにエラーが起こってしまうのでそのための処理をしておきましょう。

```dart diff
  floatingActionButton: FloatingActionButton(
    onPressed: () async {
-     final String title = await Navigator.of(context)
+     final String? title = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => CreatePage()));
-     _addTodo(title);
+     if (title != null && title != "") _addTodo(title);
    },
  ),
```

:::message
実際の現場では、同僚とコードレビューを実施し、こういう問題を解決しながら成長していきます。

String? は null 許容と意味なのですが、ここは興味があれば調べてみてください。
if (title != null && title != "") _addTodo(title); で、title が設定されていれば、TODOを追加する..という意味になります。
:::

これで TODO を追加する機能が実装できました。

次のチャプターでは TODO の削除ができるように実装していきましょう。