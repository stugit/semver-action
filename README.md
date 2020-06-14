# semver-action

This action finds the most recent semver tag, and bumps it up depending on the tag #major, #minor, or #patch in the merge comment.
Without the tag it will bump up the minor number.

## Inputs

 #major
 #minor
 #patch

## Outputs

### `tag`

v1.0.1 or 1.0.1

## Example usage

```
uses: stugit/semver-action@v1
with:
  source: 'name-of-the-repo'
  DEFAULT_DUMP: 'patch'
  RELEASE_BRANCHES: 'release1,release2'
  CUSTOM_TAG: 'mock-'
  DRY_RUN: true
```
