/**
 * @file        ui/overlay/quit_overlay.cpp
 *
 * @brief       "Quit the game?" confirmation dialog. See quit_overlay.h.
 *
 * @copyright   Copyright (c) 2026 Tom Clay <tomc@tctechstuff.com>
 *              All rights reserved.
 *
 * @license     BSD 3-Clause License
 *              See LICENSE file in the project root for full license text.
 */
#include <rex/ui/overlay/quit_overlay.h>

#include <algorithm>
#include <cstdio>
#include <utility>
#include <vector>

#include <imgui.h>

namespace rex::ui {

namespace {

// X_INPUT_GAMEPAD_* bits, kept local so the UI layer does not depend on input.
constexpr uint16_t kPadDpadUp = 0x0001;
constexpr uint16_t kPadDpadDown = 0x0002;
constexpr uint16_t kPadDpadLeft = 0x0004;
constexpr uint16_t kPadDpadRight = 0x0008;
constexpr uint16_t kPadA = 0x1000;
constexpr uint16_t kPadB = 0x2000;
constexpr int16_t kStickThreshold = 16000;

}  // namespace

QuitDialog::QuitDialog(ImGuiDrawer* imgui_drawer, PollGamepadCallback poll_gamepad,
                       ActionCallback on_quit, ActionCallback on_cancel, FrameRate frame_rate,
                       Vsync vsync)
    : ImGuiDialog(imgui_drawer),
      poll_gamepad_(std::move(poll_gamepad)),
      on_quit_(std::move(on_quit)),
      on_cancel_(std::move(on_cancel)),
      frame_rate_(std::move(frame_rate)),
      vsync_(std::move(vsync)) {}

void QuitDialog::OnDraw(ImGuiIO& io) {
  if (acted_) {
    return;
  }

  // Gamepad: edge-triggered, so a held button or stick moves only once.
  bool confirm = false;
  bool cancel = false;
  int move_x = 0;
  int move_y = 0;
  if (poll_gamepad_) {
    Gamepad pad = poll_gamepad_();
    uint16_t buttons = pad.connected ? pad.buttons : 0;
    uint16_t pressed = buttons & ~previous_buttons_;
    previous_buttons_ = buttons;
    move_x = (pressed & kPadDpadLeft) ? -1 : (pressed & kPadDpadRight) ? 1 : 0;
    move_y = (pressed & kPadDpadUp) ? -1 : (pressed & kPadDpadDown) ? 1 : 0;
    int stick_direction = 0;
    if (pad.connected && pad.thumb_ly > kStickThreshold) {
      stick_direction = -1;
    } else if (pad.connected && pad.thumb_ly < -kStickThreshold) {
      stick_direction = 1;
    }
    if (stick_direction != 0 && stick_direction != previous_stick_direction_) {
      move_y = stick_direction;
    }
    previous_stick_direction_ = stick_direction;
    confirm |= (pressed & kPadA) != 0;
    cancel |= (pressed & kPadB) != 0;
  }

  // Keyboard, once the opening key press has been consumed.
  if (++frames_drawn_ > 2) {
    move_x = ImGui::IsKeyPressed(ImGuiKey_LeftArrow, false)    ? -1
             : ImGui::IsKeyPressed(ImGuiKey_RightArrow, false) ? 1
                                                               : move_x;
    move_y = ImGui::IsKeyPressed(ImGuiKey_UpArrow, false)     ? -1
             : ImGui::IsKeyPressed(ImGuiKey_DownArrow, false) ? 1
                                                              : move_y;
    confirm |= ImGui::IsKeyPressed(ImGuiKey_Enter, false) ||
               ImGui::IsKeyPressed(ImGuiKey_KeypadEnter, false) ||
               ImGui::IsKeyPressed(ImGuiKey_Space, false);
    cancel |= ImGui::IsKeyPressed(ImGuiKey_Escape, false);
  }

  // Up and down go through the rows, top to bottom; left and right change the
  // row's value, or go between the buttons.
  const int rate_count = int(frame_rate_.rates.size());
  const bool has_vsync = bool(vsync_.set);
  std::vector<int> rows;
  if (rate_count) rows.push_back(kFrameRate);
  if (has_vsync) rows.push_back(kVsync);
  rows.push_back(kCancel);
  if (move_y != 0) {
    const int current_row = selection_ == kQuit ? kCancel : selection_;
    const auto found = std::find(rows.begin(), rows.end(), current_row);
    const int index = std::clamp(int(found - rows.begin()) + move_y, 0, int(rows.size()) - 1);
    if (rows[index] != current_row) selection_ = rows[index];
  }
  if (selection_ == kFrameRate) {
    if (move_x != 0) {
      int index = 0;
      for (int i = 0; i < rate_count; ++i) {
        if (frame_rate_.rates[i] == frame_rate_.current) index = i;
      }
      frame_rate_.current = frame_rate_.rates[(index + move_x + rate_count) % rate_count];
      if (frame_rate_.set) {
        frame_rate_.set(frame_rate_.current);
      }
    }
  } else if (selection_ == kVsync) {
    if (move_x != 0) {
      vsync_.enabled = !vsync_.enabled;
      vsync_.set(vsync_.enabled);
    }
  } else if (move_x != 0) {
    selection_ = selection_ == kCancel ? kQuit : kCancel;
  }

  ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x * 0.5f, io.DisplaySize.y * 0.5f),
                          ImGuiCond_Always, ImVec2(0.5f, 0.5f));
  ImGui::SetNextWindowBgAlpha(0.92f);
  ImGui::PushFont(nullptr, 26.0f);
  if (ImGui::Begin("##quit_dialog", nullptr,
                   ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoSavedSettings |
                       ImGuiWindowFlags_NoNav | ImGuiWindowFlags_AlwaysAutoResize)) {
    const auto option = [](bool selected, const char* text) {
      ImGui::TextColored(selected ? ImVec4(0.45f, 1.0f, 0.5f, 1.0f) : ImVec4(0.6f, 0.6f, 0.6f, 1.0f),
                         "%s %s %s", selected ? "<" : " ", text, selected ? ">" : " ");
    };
    if (rate_count) {
      char text[64];
      std::snprintf(text, sizeof(text), "Frame rate: %d FPS", frame_rate_.current);
      option(selection_ == kFrameRate, text);
    }
    if (has_vsync) {
      option(selection_ == kVsync, vsync_.enabled ? "VSync: On" : "VSync: Off");
    }
    if (rate_count || has_vsync) {
      ImGui::Dummy(ImVec2(0.0f, 8.0f));
    }
    ImGui::TextUnformatted("Quit the game?");
    ImGui::PushFont(nullptr, 18.0f);
    ImGui::TextDisabled("Unsaved progress is lost.");
    ImGui::PopFont();
    ImGui::Dummy(ImVec2(0.0f, 8.0f));
    const ImVec2 button_size(180.0f, 0.0f);
    const char* labels[] = {"Cancel", "Quit"};
    for (int i = kCancel; i <= kQuit; ++i) {
      if (i != kCancel) {
        ImGui::SameLine();
      }
      // The selection must read at a glance from the couch: a bright, outlined
      // button against a dim one.
      const bool selected = selection_ == i;
      const ImVec4 fill = selected ? ImVec4(0.20f, 0.62f, 0.25f, 1.0f)
                                   : ImVec4(0.18f, 0.18f, 0.18f, 1.0f);
      ImGui::PushStyleColor(ImGuiCol_Button, fill);
      ImGui::PushStyleColor(ImGuiCol_ButtonHovered, fill);
      ImGui::PushStyleColor(ImGuiCol_Text, selected ? ImVec4(1.0f, 1.0f, 1.0f, 1.0f)
                                                    : ImVec4(0.6f, 0.6f, 0.6f, 1.0f));
      ImGui::PushStyleColor(ImGuiCol_Border, ImVec4(1.0f, 1.0f, 1.0f, selected ? 1.0f : 0.0f));
      ImGui::PushStyleVar(ImGuiStyleVar_FrameBorderSize, 2.0f);
      if (ImGui::Button(labels[i], button_size)) {
        selection_ = i;
        confirm = true;
      }
      ImGui::PopStyleVar();
      ImGui::PopStyleColor(4);
    }
    ImGui::PushFont(nullptr, 16.0f);
    ImGui::TextDisabled(rows.size() > 1 ? "Up / Down: row    A / Enter: select    B / Esc: back"
                                   : "A / Enter: select    B / Esc: back");
    ImGui::PopFont();
  }
  ImGui::End();
  ImGui::PopFont();

  if (cancel || (confirm && selection_ != kQuit)) {
    acted_ = true;
    if (on_cancel_) {
      on_cancel_();
    }
  } else if (confirm && selection_ == kQuit) {
    acted_ = true;
    if (on_quit_) {
      on_quit_();
    }
  }
}

}  // namespace rex::ui
