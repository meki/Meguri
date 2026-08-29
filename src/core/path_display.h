// パス表示用の純ロジック (メニュー / ステータスバーの整形)。
// UI 層が同じ整形を各所で書き直さないよう、ここに集約する。
#pragma once

#include <string>

namespace meguri::core {

// パスからファイル名部分を返す (区切りが無ければパス全体)。
std::wstring file_name(const std::wstring& path);

// パスから親フォルダ部分を返す (末尾の区切りは含めない)。
// 区切りが無ければ空文字列。ルート直下は "C:\" のように区切りを残す。
std::wstring parent_directory(const std::wstring& path);

// text が max_chars を超える場合、中央を "..." に置き換えて max_chars 以下にする。
// サロゲートペアの途中では切らない。max_chars <= 3 のときは "..." を返す。
std::wstring ellipsize_middle(const std::wstring& text, size_t max_chars);

// Win32 メニュー項目用に & をエスケープする (& はニーモニック記号として消費される)。
std::wstring escape_menu_text(const std::wstring& text);

// メニュー項目に載せる表示文字列 (中央省略 → & エスケープ)。
std::wstring menu_label(const std::wstring& text, size_t max_chars);

}  // namespace meguri::core
