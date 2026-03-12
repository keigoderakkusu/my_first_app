{ pkgs, ... }: {
  channel = "stable-24.05";

  packages = [
    pkgs.flutter
    pkgs.jdk17
    # Linux build dependencies
    pkgs.pkg-config
    pkgs.cmake
    pkgs.ninja
    pkgs.gtk3
    pkgs.libappindicator-gtk3
    pkgs.libsecret
    pkgs.xdg-utils
    pkgs.glib
    pkgs.pango
    pkgs.harfbuzz
    pkgs.gdk-pixbuf
    pkgs.cairo
    pkgs.atk
    pkgs.at-spi2-atk
    pkgs.dbus
    pkgs.epoxy
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
      onStart = {
        flutter-doctor = "flutter doctor";
      };
    };

    previews = {
      enable = true;
      previews = {
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
