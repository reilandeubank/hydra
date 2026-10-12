{
  description = "Hydra dev environment (Android builds)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          # Keep in sync with node_modules/react-native/gradle/libs.versions.toml
          buildToolsVersion = "36.0.0";
          ndkVersion = "27.1.12297006";
          cmakeVersion = "3.30.5";

          androidComposition = pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ "36" ];
            buildToolsVersions = [
              buildToolsVersion
              # AGP's default, used by modules that don't set buildToolsVersion (e.g. modules/app-icons)
              "35.0.0"
            ];
            ndkVersions = [
              ndkVersion
              # AGP's default, used by modules that don't set ndkVersion (e.g. expo-updates)
              "27.0.12077973"
            ];
            cmakeVersions = [
              cmakeVersion
              # AGP's default, used by modules that don't pin a CMake version (e.g. react-native-screens)
              "3.22.1"
            ];
            includeNDK = true;
            includeEmulator = false;
            includeSystemImages = false;
          };
          androidSdk = androidComposition.androidsdk;
          sdkRoot = "${androidSdk}/libexec/android-sdk";
          jdk = pkgs.jdk17;
        in
        {
          default = pkgs.mkShell {
            packages = [
              androidSdk
              jdk
              pkgs.nodejs_24
              pkgs.bun
            ];

            JAVA_HOME = jdk.home;
            ANDROID_HOME = sdkRoot;
            ANDROID_SDK_ROOT = sdkRoot;
            ANDROID_NDK_ROOT = "${sdkRoot}/ndk/${ndkVersion}";
            CMAKE_VERSION = cmakeVersion;

            # The aapt2 binary Gradle downloads from Maven is not runnable on NixOS
            GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${sdkRoot}/build-tools/${buildToolsVersion}/aapt2";

            shellHook = ''
              export SENTRY_DISABLE_AUTO_UPLOAD="''${SENTRY_DISABLE_AUTO_UPLOAD:-true}"
            '';
          };
        }
      );
    };
}
