#include "shell_reveal.h"

#include <shlobj.h>
#include <windows.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")

namespace meguri::io {

bool reveal_in_explorer(const std::wstring& path) {
    if (path.empty()) return false;

    PIDLIST_ABSOLUTE pidl = nullptr;
    if (FAILED(SHParseDisplayName(path.c_str(), nullptr, &pidl, 0, nullptr)) || !pidl) {
        return false;  // 既に削除された等でパスを解決できない
    }
    const HRESULT hr = SHOpenFolderAndSelectItems(pidl, 0, nullptr, 0);
    CoTaskMemFree(pidl);
    return SUCCEEDED(hr);
}

}  // namespace meguri::io
