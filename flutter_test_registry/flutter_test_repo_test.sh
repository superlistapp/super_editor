set -e

(cd ./attributed_text; dart test)
(cd ./super_editor; flutter test)
(cd ./super_text_layout; flutter test)
