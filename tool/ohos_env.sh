# HarmonyOS / OpenHarmony build environment for FinnAI.
#
# Source this before any `flutter build hap`, `hvigorw`, `ohpm` or `hdc`
# command:
#
#   source tool/ohos_env.sh
#
# It exports the four variables the Flutter OHOS fork, hvigor and ohpm all
# need (DevEco SDK root, JDK 17, DevEco bundled Node, CLI-tools bin), plus a
# PATH entry for `hdc`.
#
# The LANG/LC_ALL/TZ trio is deliberately NOT set here: it is only needed to
# install/download HarmonyOS emulator images, which are geo-gated to the
# Chinese mainland outside of a zh_CN locale. `tool/install_ohos_emulator.sh`
# sets it for that one command.

_DOT_TOOL_HOME="${DOT_TOOL_HOME:-$HOME/Developer/command-line-tools}"

export DEVECO_SDK_HOME="$_DOT_TOOL_HOME/sdk"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export PATH="$_DOT_TOOL_HOME/bin:$PATH"
export PATH="$_DOT_TOOL_HOME/sdk/default/openharmony/toolchains:$PATH"
export PATH="$_DOT_TOOL_HOME/tool/node/bin:$PATH"

unset _DOT_TOOL_HOME