// エクスプローラー連携。項目の場所をユーザーに見せるための操作をまとめる。
#pragma once

#include <string>

namespace meguri::io {

// path を含むフォルダをエクスプローラーで開き、その項目を選択状態にする。
// COM 初期化済みのスレッド (GUI スレッド) から呼ぶこと。失敗したら false。
bool reveal_in_explorer(const std::wstring& path);

}  // namespace meguri::io
