//! A tiny event store: enough Rust surface to exercise every highlight group.
use std::collections::HashMap;
use std::fmt;

/// Where a reading came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Source {
    Sensor(u16),
    Manual,
}

/// One measurement, borrowed from the input line.
#[derive(Debug)]
pub struct Reading<'a> {
    pub source: Source,
    pub label: &'a str,
    pub value: f64,
}

pub trait Summary {
    fn summarize(&self) -> String;
    fn is_alarm(&self) -> bool {
        false
    }
}

type Store<'a> = HashMap<Source, Vec<Reading<'a>>>;

const LIMIT: f64 = 42.5;
static NAME: &str = "store";

impl<'a> Summary for Reading<'a> {
    fn summarize(&self) -> String {
        format!("{}={:.2} ({:?})", self.label, self.value, self.source)
    }

    fn is_alarm(&self) -> bool {
        self.value > LIMIT
    }
}

impl fmt::Display for Source {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Source::Sensor(id) => write!(f, "sensor#{id}"),
            Source::Manual => f.write_str("manual"),
        }
    }
}

#[derive(Debug)]
pub enum ParseError {
    Missing(&'static str),
    Number(std::num::ParseFloatError),
}

fn parse_line(line: &str) -> Result<Reading<'_>, ParseError> {
    let mut parts = line.split(',');
    let id = parts.next().ok_or(ParseError::Missing("id"))?;
    let label = parts.next().ok_or(ParseError::Missing("label"))?;
    let value = parts
        .next()
        .ok_or(ParseError::Missing("value"))?
        .trim()
        .parse::<f64>()
        .map_err(ParseError::Number)?;
    let source = match id.parse::<u16>() {
        Ok(n) => Source::Sensor(n),
        Err(_) => Source::Manual,
    };
    Ok(Reading { source, label, value })
}

fn alarms<'a, T: Summary + 'a>(items: impl IntoIterator<Item = &'a T>) -> Vec<String> {
    items.into_iter().filter(|r| r.is_alarm()).map(Summary::summarize).collect()
}

fn main() {
    let input = "1,temp, 21.0\n2,pressure,51.3\nx,note,3\n7,temp,oops";
    let mut store: Store = HashMap::new();
    let mut failed = 0usize;
    for line in input.lines() {
        match parse_line(line) {
            Ok(r) => store.entry(r.source).or_default().push(r),
            Err(e) => {
                eprintln!("{NAME}: skipping {line:?}: {e:?}");
                failed += 1;
            }
        }
    }
    let unused = 3;
    let all: Vec<&Reading> = store.values().flatten().collect();
    for msg in alarms(all.iter().copied()) {
        println!("ALARM {msg}");
    }
    let raw = &LIMIT as *const f64;
    let limit = unsafe { *raw };
    println!("{} sources, {failed} failed, limit {limit}", store.len());
}
