#![expect(incomplete_features, reason = "I'll trust it will work until it doesn't.")]
#![feature(lazy_type_alias)]

use std::{fmt::Display, result::Result as StdResult};

use ciborium::{Value, cbor};
#[cfg(target_arch = "wasm32")]
use wasm_minimal_protocol::{initiate_protocol, wasm_func};

pub type Result<T, E = String>
    = StdResult<T, E>
where
    E: Into<String>;

type InputTriplet = (Vec<(Value, Value)>, Vec<(Value, Value)>, Vec<Value>);
type RefInputTriplet<'a> = (&'a [(Value, Value)], &'a [(Value, Value)], &'a [Value]);
type ConversionTriplet = (Vec<usize>, Vec<usize>, Vec<usize>);

const EVENTS_PER_DAY: usize = 6;
const SCHEDULE_DAYS: usize = 7;

#[derive(Debug)]
enum Event {
    Day(usize),
    Subject(usize),
    Project(usize),
    Other(String),
}

#[cfg(target_arch = "wasm32")]
initiate_protocol!();

#[cfg_attr(target_arch = "wasm32", wasm_func)]
pub fn schedule(subjects: &[u8], projects: &[u8], days: &[u8]) -> Result<Vec<u8>> {
    #[inline]
    #[cold]
    fn err(e: impl Display) -> String { e.to_string() }

    let (subjects, projects, days) = check_types(
        ciborium::from_reader(subjects).map_err(err)?,
        ciborium::from_reader(projects).map_err(err)?,
        ciborium::from_reader(days).map_err(err)?,
    )?;
    let (idx_subjects, idx_projects, idx_days) = index(&subjects, &projects, &days);
    let result = cbor!(translate(
        (&subjects, &projects, &days),
        &resolve(&idx_subjects, &idx_projects, &idx_days)
    )?)
    .map_err(err)?;
    let mut output = Vec::new();
    ciborium::into_writer(&result, &mut output).map_err(err)?;

    Ok(output)
}

fn check_types(subjects: Value, projects: Value, days: Value) -> Result<InputTriplet> {
    #[inline]
    #[cold]
    fn err<'a>(reason: &'a str) -> impl Fn(Value) -> &'a str { move |_| reason }

    Ok((
        subjects.into_map().map_err(err("`subjects` isn't a dictionary"))?,
        projects.into_map().map_err(err("`projects` isn't a dictionary"))?,
        days.into_array().map_err(err("`days` isn't an array"))?,
    ))
}

fn index(
    subjects: &[(Value, Value)],
    projects: &[(Value, Value)],
    days: &[Value],
) -> ConversionTriplet {
    macro_rules! mapper {
        ($item:expr) => {{
            (0..$item.len()).fold(Vec::with_capacity($item.len()), |mut out, i| {
                out.push(i);
                out
            })
        }};
    }

    (mapper!(subjects), mapper!(projects), mapper!(days))
}

fn resolve(subjects: &[usize], projects: &[usize], days: &[usize]) -> Vec<Vec<Event>> {
    days.iter()
        .fold(
            (Vec::with_capacity(SCHEDULE_DAYS), None, None),
            |(mut events, current_subject, current_project), day| {
                let (current_subject, current_project, mut out) = (
                    current_subject.unwrap_or_default(),
                    current_project.unwrap_or_default(),
                    Vec::with_capacity(EVENTS_PER_DAY),
                );
                out.push(Event::Day(*day));
                for subject in subjects.iter().cycle().skip(current_subject).take(3) {
                    out.push(Event::Subject(*subject));
                }
                out.push(Event::Other("Break".to_string()));
                out.push(Event::Other("Competitive programming".to_string()));
                for project in projects.iter().cycle().skip(current_project).take(1) {
                    out.push(Event::Project(*project));
                }
                events.push(out);

                (
                    events,
                    Some((current_subject + 3) % subjects.len()),
                    Some((current_project + 1) % projects.len()),
                )
            },
        )
        .0
}

fn translate(
    (subjects, projects, days): RefInputTriplet,
    resolution: &Vec<Vec<Event>>,
) -> Result<Vec<Vec<Value>>> {
    let mut output = Vec::with_capacity(resolution.len());
    for day in resolution {
        let mut day_output = Vec::with_capacity(day.len());
        for event in day {
            match event {
                | Event::Day(day) => day_output.push(days[*day].clone()),
                | Event::Subject(subject) => day_output.push(subjects[*subject].clone().1),
                | Event::Project(project) => day_output.push(projects[*project].clone().1),
                | Event::Other(other) => day_output.push(
                    cbor!(other).map_err(|_| "failed to map custom values into cbor `Value`")?,
                ),
            }
        }
        output.push(day_output);
    }

    Ok(output)
}
