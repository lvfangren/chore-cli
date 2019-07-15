export async function addBabel(options: ChoreOptions) {

  const { features } = options;

  const babelConfig: any = {
    presets: [
      ['@babel/preset-env',
        {
          'useBuiltIns': 'usage'
        }
      ],
    ],
    'plugins': [
      '@babel/plugin-transform-runtime',
      '@babel/proposal-class-properties',
      '@babel/proposal-object-rest-spread'
    ]
  };


  options.devDeps = [...options.devDeps, '@babel/cli', '@babel/core', '@babel/preset-env', '@babel/plugin-transform-runtime',
    '@babel/plugin-proposal-class-properties',
    '@babel/plugin-proposal-object-rest-spread'];
  options.deps = [...options.deps, '@babel/polyfill', '@babel/runtime'];


  if (features.includes('typescript')) {
    babelConfig.presets.push('@babel/preset-typescript');
    options.devDeps = [...options.devDeps, '@babel/preset-typescript'];
  }

  if (features.includes('react')) {
    babelConfig.presets.push('@babel/preset-react');
    options.devDeps = [...options.devDeps, '@babel/preset-react'];
  }

  Object.assign<FileContent, FileContent>(options.files, {
    '.babelrc': JSON.stringify(babelConfig, null, 2),
  });

}
