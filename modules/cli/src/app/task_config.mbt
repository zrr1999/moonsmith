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
  allowed : Array[String],
) -> Map[String, @toml.TomlValue] raise {
  guard value is TomlTable(fields) else { fail("\{section} must be a table") }
  for key, _ in fields {
    guard allowed.contains(key) else {
      fail("unknown task field: \{section}.\{key}")
    }
  }
  fields
}

///|
fn task_section(
  fields : Map[String, @toml.TomlValue],
  name : String,
  allowed : Array[String],
) -> Map[String, @toml.TomlValue] raise {
  guard fields.get(name) is Some(value) else {
    fail("missing task section: \{name}")
  }
  task_fields(value, name, allowed)
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
fn parse_task(source : String) -> TaskConfig raise {
  let fields = task_fields(@toml.parse(source), "task", [
    "name", "seed_start", "sample_count", "generation", "execution", "reduction",
    "output",
  ])
  let generation = task_section(fields, "generation", [
    "max_nodes", "max_depth", "max_attempts",
  ])
  let execution = task_section(fields, "execution", [
    "configurations", "build_timeout_ms", "run_timeout_ms",
  ])
  let reduction = task_section(fields, "reduction", ["candidate_limit"])
  let output = task_section(fields, "output", ["directory"])
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
  task
}
