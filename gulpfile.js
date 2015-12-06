var FromStream, cache, changed, coffee, del, dest, from, gulp, gutil, mocha, onErrorContinue, path, plumber, src, task, xtask;

path = require('path');

gulp = require('gulp');

gutil = require('gulp-util');

changed = require('gulp-changed');

cache = require('gulp-cached');

plumber = require('gulp-plumber');

del = require('del');

mocha = require('gulp-mocha');

xtask = function() {};

task = gulp.task.bind(gulp);

src = gulp.src.bind(gulp);

from = function(source, options) {
  if (options == null) {
    options = {
      dest: 'app',
      cache: 'cache'
    };
  }
  if (options.dest == null) {
    options.dest = 'app';
  }
  if (options.cache == null) {
    options.cache = 'cache';
  }
  return src(source).pipe(changed(options.dest)).pipe(cache(options.cache)).pipe(plumber());
};

dest = gulp.dest.bind(gulp);

FromStream = from('').constructor;

FromStream.prototype.to = function(dst) {
  return this.pipe(dest(dst));
};

FromStream.prototype.pipelog = function(obj, log) {
  if (log == null) {
    log = gutil.log;
  }
  return this.pipe(obj).on('error', log);
};

coffee = require('gulp-coffee');

task('coffee', function(cb) {
  return from(['index.coffee', 'test-util.coffee'], {
    cache: 'coffee'
  }).pipelog(coffee({
    bare: true
  })).pipe(dest('./'));
});

onErrorContinue = function(err) {
  console.log(err.stack);
  return this.emit('end');
};

task('mocha', function() {
  return src('test-*.js').pipe(mocha({
    reporter: 'spec'
  })).on("error", onErrorContinue);
});

task('default', ['coffee', 'mocha']);
