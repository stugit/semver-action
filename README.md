# semver docker action

This action finds the most recent semver tag, and bumps it up depending on the tag #major, #minor, or #patch in the merge comment.
Without the tag it will bump up just the patch number.

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
  
```
