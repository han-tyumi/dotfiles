- Prefer descriptive variable names over comments. Prefer to let the code document itself rather than using verbose comments.
- Use punctuation for JSDoc parameters and similar.
- Avoid using the `any` type in TypeScript files.
- Avoid non-null assertions in TypeScript.
- Avoid using 1 letter variable names in TypeScript and JavaScript.
- Prefer JavaScript functions to have a maximum 2 arguments. Put the rest into an options object.

  When designing function interfaces, stick to the following rules:

  1. A function should take 0-2 required arguments, plus (if necessary) an options object (so max 3 total).

  2. Optional parameters should generally go into the options object.

     An optional parameter that's not in an options object might be acceptable if there is only one, and it seems inconceivable that we would add more optional parameters in the future.

  3. The 'options' argument is the only argument that is a regular 'Object'.

     Other arguments can be objects, but they must be distinguishable from a 'plain' Object runtime, by having either:
     - a distinguishing prototype (e.g. Array, Map, Date, class MyThing).
     - a well-known symbol property (e.g. an iterable with Symbol.iterator).

     This allows the API to evolve in a backwards compatible way, even when the position of the options object changes.

- Comments should use proper capitalization and punctuation when possible.
- Add a blank line before comments so they visually pair with the code they describe.

@RTK.md
