Put XML files here that should either pass or fail validation against the
XSD schema.

## Testing All Versions

For files that should validate against every version of the schema, use the
`all` directory.

- `tests/all/valid/<FILE>`
- `tests/all/invalid/<FILE>`

For example:

- `tests/all/valid/foo.xml` should **PASS** validation. It will be validated
  against every version of the schema, and the tests will fail if it does not
  validate.
- `tests/all/invalid/bar.xml` should **FAIL** validation. It will be validated
  against every version of the schema, and the tests will fail if it validates
  as error-free.

## Testing Individual Versions

For individual versions of the XSD, use the following structure:

- `tests/<VERSION>/valid/<FILE>`
- `tests/<VERSION>/invalid/<FILE>`

For example:

- `tests/v2.1/valid/foo.xml` should **PASS** validation. It will be validated
  against version 2.1 of the schema, and the tests will fail if it does not
  validate.
- `tests/v2.1/invalid/bar.xml` should **FAIL** validation. It will be validated
  against version 2.1 of the schema, and the tests will fail if it validates as
  error-free.
