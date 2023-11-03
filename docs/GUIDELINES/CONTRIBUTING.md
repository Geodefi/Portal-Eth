# Contributing Guidelines

1. Open an issue
2. Fork and clone the repo
3. Create a local branch with `git checkout -b your-branch-name`
4. Commit your changes to the local branch and push
5. Submit a Pull Request  

## Opening an issue

**For serious bugs please do not open an issue, instead refer to our [security policy](./SECURITY.md) for appropriate steps.**

To suggest a feature or report a minor bug you can [open an issue](https://github.com/Geodefi/Portal-Eth/issues/new/choose).

Before opening an issue, be sure to search through the existing open and closed issues, and consider posting a comment in one of those instead.

When requesting a new feature, include as many details as you can, especially around the use cases that motivate it. Features are prioritized according to the impact they may have on the ecosystem, so we appreciate information showing that the impact could be high.

## Submitting a pull request

If you would like to contribute code or documentation you may do so by forking the repository and submitting a pull request.

Any non-trivial code contribution must be first discussed with the maintainers in an issue (see [Opening an issue](#opening-an-issue)). Only very minor changes are accepted without prior discussion.

Make sure to read and follow the engineering guidelines. Run linter and tests to make sure your pull request is acceptable before submitting it.

Changelog entries should be added to each pull request by using [Changesets](https://github.com/changesets/changesets/).

> To keep `master` branch pointing to remote repository and make
> pull requests from branches on your fork. To do this, run:
>
> ```sh
> git remote add upstream https://github.com/Geodefi/Portal-Eth
> git fetch upstream
> git branch --set-upstream-to=upstream/master master
> ```
