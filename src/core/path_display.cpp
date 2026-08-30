#include "path_display.h"

namespace meguri::core {

namespace {

constexpr wchar_t kSeparators[] = L"\\/";
constexpr wchar_t kEllipsis[] = L"...";
constexpr size_t kEllipsisLength = 3;

bool is_high_surrogate(wchar_t c) { return c >= 0xD800 && c <= 0xDBFF; }
bool is_low_surrogate(wchar_t c) { return c >= 0xDC00 && c <= 0xDFFF; }

}  // namespace

std::wstring file_name(const std::wstring& path) {
    const size_t pos = path.find_last_of(kSeparators);
    return pos == std::wstring::npos ? path : path.substr(pos + 1);
}

std::wstring parent_directory(const std::wstring& path) {
    const size_t pos = path.find_last_of(kSeparators);
    if (pos == std::wstring::npos) return std::wstring();
    // "C:\name" や "\name" のようにルート直下なら区切りを残す
    if (pos == 0 || path[pos - 1] == L':') return path.substr(0, pos + 1);
    return path.substr(0, pos);
}

std::wstring ellipsize_middle(const std::wstring& text, size_t max_chars) {
    if (text.size() <= max_chars) return text;
    if (max_chars <= kEllipsisLength) return kEllipsis;

    const size_t keep = max_chars - kEllipsisLength;
    size_t head = (keep + 1) / 2;  // 奇数のときは前を長くする
    size_t tail = keep - head;
    // サロゲートペアを分断しないように境界をずらす
    if (head > 0 && is_high_surrogate(text[head - 1])) --head;
    if (tail > 0 && is_low_surrogate(text[text.size() - tail])) --tail;

    std::wstring result = text.substr(0, head);
    result += kEllipsis;
    if (tail > 0) result += text.substr(text.size() - tail);
    return result;
}

std::wstring escape_menu_text(const std::wstring& text) {
    std::wstring result;
    result.reserve(text.size());
    for (wchar_t c : text) {
        result += c;
        if (c == L'&') result += c;
    }
    return result;
}

std::wstring menu_label(const std::wstring& text, size_t max_chars) {
    return escape_menu_text(ellipsize_middle(text, max_chars));
}

}  // namespace meguri::core
