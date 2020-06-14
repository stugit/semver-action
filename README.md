# semver-action

This action finds the most recent semver tag, and bumps it up depending on the tag #major, #minor, or #patch in the merge comment.
Without the tag it will bump up the minor number.

## Inputs

### Merge Comment 
 #major
 #minor
 #patch
 
### Branch Name
If you name your branch /feature/<branch name>, when the code is merged to master the action will bump up the minor number instead of the patch number if that is the default. 

### DEFAULT_BUMP
By default the active will bump up the minor number when the code is merged to master, might be better for you to can change the default to patch, 
e.g. 
```
DEFAULT_BUMP='patch'
```

### DRY_RUN
Can add run without creating a tag.

e.g. 
```
DRY_RUN: 'true'
```

### WITH_V
Can add a v prefix e.g. v1.0.0 but default it's without, e.g. 1.0.0.

e.g. 
```
WITH_V: true
```

## Outputs

### A git tag

v1.0.1 or 1.0.1 or new_prefix_v1.0.1

## Example usage

```
uses: stugit/semver-action@v1
with:
  source: 'name-of-the-repo'
  DEFAULT_BUMP: 'patch'
  RELEASE_BRANCHES: 'release1,release2'
  DRY_RUN: true
```
