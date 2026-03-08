#import plugin("scheduler.wasm"): schedule as __schedule

#let scheduler(subjects, projects, days) = {
  assert.eq(type(subjects), dictionary)
  assert.eq(type(projects), dictionary)
  assert.eq(type(days), array)
  for (_, value) in subjects { assert.eq(type(value), content) }
  for (_, value) in projects { assert.eq(type(value), content) }
  for entry in days { assert.eq(type(entry), content) }

  cbor(__schedule(cbor.encode(subjects), cbor.encode(projects), cbor.encode(days)))
}
