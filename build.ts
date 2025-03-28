import { type Build } from 'xbuild';

const build: Build = {
    common: {
        project: 'msf_gif',
        archs: ['x64'],
        variables: [],
        defines: ['MSF_GIF_IMPL'],
        options: [],
        copy: {
            'msf_gif/msf_gif.h': 'msf_gif/msf_gif.c'
        },
        subdirectories: [],
        libraries: {
            'msf_gif': {
                sources: ['msf_gif/msf_gif.c']
            }
        },
        buildDir: 'build',
        buildOutDir: 'libs',
        buildFlags: []
    },
    platforms: {
        win32: {
            windows: {},
            android: {
                archs: ['x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'],
            }
        },
        linux: {
            linux: {}
        },
        darwin: {
            macos: {}
        }
    }
}

export default build;