SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
realm deny --all
cat "${SCRIPT_DIR}/atd_users_list.txt" | xargs realm permit
# remove permittion
realm permit --withdraw a-kojima s-nagayama s-hiai shii y-hishiba tm-kimura h-kishi
