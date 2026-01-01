package main

import "core:fmt"
import "core:log"
import os "core:os/os2"
import "core:strconv"
import "core:strings"
import "core:time"

main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger()
	}

	if len(os.args) != 2 {
		fmt.eprintfln("Wrong number of argument")
	}
	path := os.args[1]

	if !os.exists(path) {
		f, create_file_err := os.create(path)
		os.write_string(f, "00:00:00\n")
		os.close(f)
		return
	}

	file, open_file_err := os.open(path, {.Read, .Write})
	ensure(open_file_err == nil)
	defer {
		err := os.close(file)
		ensure(err == nil)
	}
	file_info, stat_err := os.stat(path, context.allocator)
	ensure(stat_err == nil)

	line_length: u16 = 0
	for i := file_info.size - 2; i >= 0; i -= 1 {
		char: [1]u8
		os.read_at(file, ([]u8)(char[:]), i)
		if char[0] == '\n' do break
		line_length += 1
	}
	pre_line := make([dynamic]u8, line_length)
	os.read_at(file, pre_line[:], (file_info.size - 1) - (i64)(line_length))
	log.debug(transmute(string)(pre_line[:]))

	pre_delta_time: time.Duration
	{ 	// string to Duration
		parts := strings.split((string)(pre_line[:]), ":")
		defer delete(parts)

		assert(len(parts) == 3)

		h, ok1 := strconv.parse_int(parts[0])
		m, ok2 := strconv.parse_int(parts[1])
		s, ok3 := strconv.parse_int(parts[2])
		assert(ok1 && ok2 && ok3)

		pre_delta_time =
			time.Duration(h) * time.Hour +
			time.Duration(m) * time.Minute +
			time.Duration(s) * time.Second
	}

	current_time := time.now()
	delta_time := time.diff(file_info.modification_time, current_time)
	time_stamp := pre_delta_time + delta_time

	out_buf: [time.MIN_HMS_LEN + 1]u8
	out_buf[time.MIN_HMS_LEN] = '\n'
	_ = time.duration_to_string_hms(time_stamp, out_buf[:time.MIN_HMS_LEN])
	os.write_at(file, out_buf[:], file_info.size)
}
