{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.jdk17
  ];

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      onCreate = {
        flutter-pub-get = "flutter pub get";
      };
    };

    previews = {
      enable = true;
      previews = {
        android = {
          command = [
            "flutter"
            "run"
            "--machine"
            "-d"
            "android"
          ];
          manager = "flutter";
        };
        web = {
          command = [
            "flutter"
            "run"
            "--machine"
            "-d"
            "web-server"
            "--web-hostname"
            "0.0.0.0"
            "--web-port"
            "$PORT"
          ];
          manager = "flutter";
        };
      };
    };
  };
}
