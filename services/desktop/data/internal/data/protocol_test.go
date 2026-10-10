package data

import "testing"

func TestDecodeRequest(t *testing.T) {
	valid := `{"schema_version":1,"request_id":"panel-1","op":"subscribe","topics":["projects","agent_runs"],"metrics":true}`
	if _, err := DecodeRequest([]byte(valid)); err != nil {
		t.Fatal(err)
	}
	controls := `{"schema_version":1,"request_id":"controls-1","op":"subscribe","topics":["projects","agent_runs","network","appearance","recording","power","notifications"]}`
	if _, err := DecodeRequest([]byte(controls)); err != nil {
		t.Fatal(err)
	}
	for _, input := range []string{
		`null`, `[]`, `{`, valid + valid,
		`{"schema_version":2,"request_id":"x","op":"subscribe","topics":["projects"]}`,
		`{"schema_version":1,"request_id":"x","op":"exec","topics":["projects"]}`,
		`{"schema_version":1,"request_id":"x","op":"subscribe","topics":["projects","projects"]}`,
		`{"schema_version":1,"request_id":"x","op":"subscribe","topics":["projects"],"metrics":true}`,
		`{"schema_version":1,"request_id":"x","op":"subscribe","topics":["projects"],"command":"bad"}`,
		`{"schema_version":1,"request_id":"x","op":"subscribe","topics":["audio"]}`,
		`{"schema_version":1,"request_id":"x","op":"dispatch","topics":["power"]}`,
		`{"schema_version":1,"request_id":"x","op":"subscribe","topics":["network"],"metrics":true}`,
	} {
		if _, err := DecodeRequest([]byte(input)); err == nil {
			t.Errorf("accepted %q", input)
		}
	}
}

func FuzzDecodeRequest(f *testing.F) {
	f.Add([]byte(`{"schema_version":1,"request_id":"x","op":"subscribe","topics":["agent_runs"]}`))
	f.Add([]byte{0xff, '\n'})
	f.Fuzz(func(t *testing.T, input []byte) {
		r, err := DecodeRequest(input)
		if err == nil && (r.SchemaVersion != Version || len(r.Topics) == 0) {
			t.Fatal("accepted invalid request")
		}
	})
}
