///|
priv struct TaskConfig {
  name : String
  seed_start : Int
  sample_count : Int
  limits : @moonbit.GenerationLimits
  configurations : Array[String]
  build_timeout_ms : Int
  run_timeout_ms : Int
  candidate_limit : Int
  output_directory : String
}

///|
fn task_fields(
  value : @toml.TomlValue,
  section : String,
) -> Map[String, @toml.TomlValue] raise {
  guard value is TomlTable(fields) else { fail("\{section} must be a table") }
  fields
}

///|
fn task_section(
  fields : Map[String, @toml.TomlValue],
  name : String,
) -> Map[String, @toml.TomlValue] raise {
  guard fields.get(name) is Some(value) else {
    fail("missing task section: \{name}")
  }
  task_fields(value, name)
}

///|
fn default_task() -> TaskConfig {
  {
    name: "differential",
    seed_start: 0,
    sample_count: 1,
    limits: @moonbit.GenerationLimits::default(),
    configurations: @moon.configurations(),
    build_timeout_ms: 30000,
    run_timeout_ms: 2000,
    candidate_limit: 16,
    output_directory: "runs",
  }
}

///|
fn TaskConfig::document(self : TaskConfig) -> @toml.TomlValue {
  TomlTable({
    "name": TomlString(self.name),
    "seed_start": TomlInteger(self.seed_start.to_int64()),
    "sample_count": TomlInteger(self.sample_count.to_int64()),
    "generation": TomlTable({
      "max_nodes": TomlInteger(self.limits.max_nodes.to_int64()),
      "max_depth": TomlInteger(self.limits.max_depth.to_int64()),
      "max_attempts": TomlInteger(self.limits.max_attempts.to_int64()),
    }),
    "execution": TomlTable({
      "configurations": TomlArray(
        self.configurations.map(name => TomlString(name)),
      ),
      "build_timeout_ms": TomlInteger(self.build_timeout_ms.to_int64()),
      "run_timeout_ms": TomlInteger(self.run_timeout_ms.to_int64()),
    }),
    "reduction": TomlTable({
      "candidate_limit": TomlInteger(self.candidate_limit.to_int64()),
    }),
    "output": TomlTable({ "directory": TomlString(self.output_directory) }),
  })
}

///|
fn merge_task_fields(
  fields : Map[String, @toml.TomlValue],
  patch : Map[String, @toml.TomlValue],
  section : String,
) -> Unit raise {
  for key, value in patch {
    let path = if section.is_empty() { key } else { "\{section}.\{key}" }
    guard fields.get(key) is Some(previous) else {
      fail("unknown task field: \{path}")
    }
    if previous is TomlTable(children) {
      merge_task_fields(children, task_fields(value, path), path)
    } else {
      fields[key] = value
    }
  }
}

///|
fn apply_task_setting(
  fields : Map[String, @toml.TomlValue],
  setting : String,
) -> String raise {
  guard setting.find("=") is Some(index) else {
    fail("--set requires KEY=VALUE: \{setting}")
  }
  let keys = setting[:index]
    .split(".")
    .map(key => key.trim().to_owned())
    .collect()
  let key = keys.join(".")
  let mut target = fields
  let mut schema = task_fields(default_task().document(), "defaults")
  for index in 0..<keys.length() {
    guard schema.get(keys[index]) is Some(expected) else {
      fail("unknown task field in --set: \{key}")
    }
    if index + 1 < keys.length() {
      schema = task_fields(expected, key)
      target = task_fields(target[keys[index]], key)
    } else if expected is TomlTable(_) {
      fail("--set requires a field such as generation.max_nodes: \{key}")
    }
  }
  let values = task_fields(
    @toml.parse("value = \{setting[index + 1:]}"),
    "--set",
  )
  guard values.length() == 1 && values.get("value") is Some(value) else {
    fail("--set requires one TOML value: \{setting}")
  }
  target[keys[keys.length() - 1]] = value
  key
}

///|
fn task_string(
  fields : Map[String, @toml.TomlValue],
  key : String,
) -> String raise {
  guard fields.get(key) is Some(TomlString(value)) && !value.trim().is_empty() else {
    fail("\{key} must be a nonempty string")
  }
  value
}

///|
fn task_int(fields : Map[String, @toml.TomlValue], key : String) -> Int raise {
  guard fields.get(key) is Some(TomlInteger(value)) &&
    value >= -2147483648L &&
    value <= 2147483647L else {
    fail("\{key} must be a signed 32-bit integer")
  }
  value.to_int()
}

///|
fn parse_task(
  source : String,
  settings? : Array[String] = [],
  directory? : String = "",
  config_directory? : String = directory,
  automatic? : () -> Int raise = @host.random_seed,
) -> TaskConfig raise {
  let fields = task_fields(default_task().document(), "defaults")
  let patch = task_fields(@toml.parse(source), "task")
  let mut explicit_seed = patch.contains("seed_start")
  let mut output_base = if patch.get("output") is Some(TomlTable(output)) &&
    output.contains("directory") {
    config_directory
  } else {
    directory
  }
  merge_task_fields(fields, patch, "")
  for setting in settings {
    match apply_task_setting(fields, setting) {
      "seed_start" => explicit_seed = true
      "output.directory" => output_base = directory
      _ => ()
    }
  }
  let generation = task_section(fields, "generation")
  let execution = task_section(fields, "execution")
  let reduction = task_section(fields, "reduction")
  let output = task_section(fields, "output")
  guard execution.get("configurations") is Some(TomlArray(values)) else {
    fail("execution.configurations must be an array")
  }
  let task : TaskConfig = {
    name: task_string(fields, "name"),
    seed_start: task_int(fields, "seed_start"),
    sample_count: task_int(fields, "sample_count"),
    limits: {
      max_nodes: task_int(generation, "max_nodes"),
      max_depth: task_int(generation, "max_depth"),
      max_attempts: task_int(generation, "max_attempts"),
    },
    configurations: values.map(value => {
      guard value is TomlString(name) else {
        fail("execution.configurations entries must be strings")
      }
      name
    }),
    build_timeout_ms: task_int(execution, "build_timeout_ms"),
    run_timeout_ms: task_int(execution, "run_timeout_ms"),
    candidate_limit: task_int(reduction, "candidate_limit"),
    output_directory: task_string(output, "directory"),
  }
  guard task.sample_count > 0 &&
    task.seed_start.to_int64() + task.sample_count.to_int64() - 1L <=
    2147483647L else {
    fail(
      "sample_count must be positive and the seed range must fit signed 32-bit integers",
    )
  }
  task.limits.validate()
  @moon.validate_plan(task.configurations)
  @moon.validate_timeouts(task.build_timeout_ms, task.run_timeout_ms)
  guard task.candidate_limit >= 0 && task.candidate_limit <= 64 else {
    fail("candidate_limit must be between 0 and 64")
  }
  let output_directory = if task.output_directory.has_prefix("/") ||
    output_base.is_empty() {
    task.output_directory
  } else {
    let separator = if output_base.has_suffix("/") { "" } else { "/" }
    "\{output_base}\{separator}\{task.output_directory}"
  }
  let seed_start = if explicit_seed {
    task.seed_start
  } else {
    // Map system entropy into the starts that fit the entire finite seed range.
    let starts = 4294967297L - task.sample_count.to_int64()
    ((automatic().to_int64() + 2147483648L) % starts - 2147483648L).to_int()
  }
  { ..task, seed_start, output_directory, }
}
