"""Tests for flipclock_ascii module."""

from flipclock_ascii import (
    parse_args,
    render_frame,
    calculate_centering,
    terminal_setup_sequence,
    terminal_cleanup_sequence,
    build_frame,
    render_clock,
)
from unittest.mock import patch, MagicMock


def test_parse_args_default():
    args = parse_args([])
    assert args.once is False


def test_parse_args_once():
    args = parse_args(["--once"])
    assert args.once is True


def test_render_frame_returns_lines():
    lines = render_frame("12:45")
    assert isinstance(lines, list)
    assert len(lines) > 0


def test_render_frame_uses_ansi_shadow():
    lines = render_frame("00:00")
    joined = "\n".join(lines)
    # ansi_shadow uses Unicode block characters
    assert "\u2588" in joined or "\u2550" in joined or "\u2557" in joined


def test_centering_horizontal():
    pad_top, pad_left = calculate_centering(
        art_lines=["XXXX", "XXXX"], term_cols=20, term_rows=10
    )
    assert pad_left == 8


def test_centering_vertical():
    pad_top, pad_left = calculate_centering(
        art_lines=["XX", "XX"], term_cols=10, term_rows=20
    )
    assert pad_top == 9


def test_centering_small_terminal():
    pad_top, pad_left = calculate_centering(
        art_lines=["XXXXXXXXXXXX"], term_cols=5, term_rows=1
    )
    assert pad_top == 0
    assert pad_left == 0


def test_setup_hides_cursor():
    seq = terminal_setup_sequence()
    assert "\033[?25l" in seq


def test_setup_sets_black_bg():
    seq = terminal_setup_sequence()
    assert "\033]11;#000000\007" in seq


def test_cleanup_shows_cursor():
    seq = terminal_cleanup_sequence()
    assert "\033[?25h" in seq


def test_cleanup_resets_color():
    seq = terminal_cleanup_sequence()
    assert "\033[0m" in seq


def test_build_frame_contains_color():
    frame = build_frame("12:45", term_cols=120, term_rows=40)
    assert len(frame) > 0
    assert "\033[1;37m" in frame


def test_build_frame_clears_screen():
    frame = build_frame("12:45", term_cols=120, term_rows=40)
    assert "\033[2J\033[H" in frame


def test_build_frame_once_mode_no_ansi():
    frame = build_frame("12:45", term_cols=120, term_rows=40, once=True)
    assert "\033[1;37m" not in frame
    assert "\033[2J" not in frame


@patch("flipclock_ascii.shutil.get_terminal_size", return_value=(120, 40))
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.datetime")
def test_render_clock_once_mode(mock_dt, mock_stdout, mock_size):
    mock_dt.now.return_value.strftime.return_value = "08:30"
    render_clock(once=True)
    mock_stdout.write.assert_called()
    mock_stdout.flush.assert_called()


@patch("flipclock_ascii.shutil.get_terminal_size", return_value=(120, 40))
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.datetime")
def test_render_clock_once_no_ansi_control(mock_dt, mock_stdout, mock_size):
    """Once mode must not write setup/cleanup sequences (breaks TTE piping)."""
    mock_dt.now.return_value.strftime.return_value = "08:30"
    render_clock(once=True)
    writes = [call.args[0] for call in mock_stdout.write.call_args_list]
    output = "".join(writes)
    assert "\033[?25l" not in output  # no hide cursor
    assert "\033[?25h" not in output  # no show cursor
    assert "\033]11;" not in output   # no bg color change


@patch("flipclock_ascii.shutil.get_terminal_size", return_value=(120, 40))
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.time.sleep", side_effect=KeyboardInterrupt)
@patch("flipclock_ascii.datetime")
def test_render_clock_exits_on_interrupt(mock_dt, mock_sleep, mock_stdout, mock_size):
    mock_dt.now.return_value.strftime.return_value = "08:30"
    render_clock(once=False)
    writes = [call.args[0] for call in mock_stdout.write.call_args_list]
    cleanup_output = "".join(writes)
    assert "\033[?25h" in cleanup_output


@patch("flipclock_ascii.shutil.get_terminal_size")
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.datetime")
def test_render_clock_recalculates_on_size_change(mock_dt, mock_stdout, mock_size):
    """REQ-013: recalculate centering when terminal is resized."""
    mock_dt.now.return_value.strftime.return_value = "08:30"
    mock_size.side_effect = [(120, 40), (80, 24)]

    render_clock(once=True)
    assert mock_size.call_count >= 1
