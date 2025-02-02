name: Auto-publish

on:
  release:
    # This specifies that the build will be triggered when we publish a release
    types: [published]

jobs:
  check_version:
    name: Check version
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ref: main

      - name: Use Node.js 14.16.1
        uses: actions/setup-node@v1
        with:
          node-version: 14.16.1
          registry-url: https://registry.npmjs.org/

      - name: Version Diff
        id: version_diff
        run: |
          current_version=$(node -pe "require('./package.json').version")
          latest_version=$(npm view <%= packageName %>@latest version)
          [[ "$current_version" != "$latest_version" ]] && changed=true || changed=false

          echo "current_version=$current_version" >> $GITHUB_ENV
          echo "latest_version=$latest_version" >> $GITHUB_ENV
          echo "changed=$changed" >> $GITHUB_ENV

      - name: Echo version info
        run: |
          echo ${{ steps.version_diff.outputs.current_version }}
          echo ${{ env.current_version }}
          echo ${{ steps.version_diff.outputs.latest_version }}

          version_changed=${{ steps.version_diff.outputs.changed }}
          echo $version_changed
          [ $version_changed == 'true' ] && echo 'New version' || echo 'No version change'

    outputs:
      version: ${{ env.current_version }}
      version_changed: ${{ env.changed }}

  build:
    name: Build
    needs: check_version
    if: ${{ needs.check_version.outputs.version_changed == 'true' }}
    runs-on: ubuntu-latest
    env:
      HUSKY: 0
    steps:
      - uses: actions/checkout@v2
        with:
          ref: main

      - name: Use Node.js 14.16.1
        uses: actions/setup-node@v1
        with:
          node-version: 14.16.1
          registry-url: https://registry.npmjs.org/

      <% if (usePnpm) { %>
      - name: Cache pnpm modules
        uses: actions/cache@v2
        env:
          cache-name: cache-pnpm-modules
        with:
          path: ~/.pnpm-store
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ matrix.node-version }}-${{ hashFiles('**/package.json') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-${{ matrix.node-version }}-

      - uses: pnpm/action-setup@v2.0.0
        with:
          version: 6.0.2
          run_install: |
            - recursive: true
              args: [--frozen-lockfile, --strict-peer-dependencies]

      - name: run lint & test & build
        run: |
          pnpm run lint
          pnpm run test
          pnpm run build
      <% } %>

      <% if (useNpm) { %>
      - name: Cache npm modules
        uses: actions/cache@v2
        env:
          cache-name: cache-npm-modules
        with:
          path: '**/node_modules'
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ matrix.node-version }}-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-${{ matrix.node-version }}-

      - name: run lint & test & build
        run: |
          npm run lint
          npm run test
          npm run build
      <% } %>

      <% if (useYarn) { %>
      - name: Cache Yarn modules
        uses: actions/cache@v2
        env:
          cache-name: cache-yarn-modules
        with:
          path: '**/node_modules'
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ matrix.node-version }}-${{ hashFiles('**/yarn.lock') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-${{ matrix.node-version }}-

      - name: run lint & test & build
        run: |
          yarn run lint
          yarn run test
          yarn run build
      <% } %>

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v1
        with:
          token: ${{secrets.CODECOV_TOKEN}}

      - name: upload artifact
        uses: actions/upload-artifact@main
        with:
          name: artifacts
          path: dist/
          retention-days: 5
          if-no-files-found: error

  publish:
    needs: build
    environment: npm-publish
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ref: main

      - name: Use Node.js 14.16.1
        uses: actions/setup-node@v1
        with:
          node-version: 14.16.1

      - name: download artifact
        uses: actions/download-artifact@main
        with:
          name: artifacts
          path: dist

      - name: publish to npm
        run: |
          cd dist
          # upgrade npm version in package.json to the tag used in the release.
          echo //registry.npmjs.org/:_authToken=$NODE_AUTH_TOKEN > .npmrc
          npm publish --access public
        env:
          # Use a token to publish to NPM. See below for how to set it up
          NODE_AUTH_TOKEN: ${{ secrets.NPM_AUTH_TOKEN }}
