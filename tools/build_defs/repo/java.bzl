# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rules for defining external Java dependencies.

java_import_external() replaces `maven_jar` and `http_jar`. It is the
recommended solution for defining third party Java dependencies that are
obtained from web servers.

This solution offers high availability, low latency, and repository
scalability at the cost of simplicity. Tooling can be used to generate
the WORKSPACE definitions from Maven metadata.

The default target in this BUILD file will always have the same name as
the repository itself. This means that other Bazel rules can depend on
it as `@repo//:repo` or `@repo` for short.

### Setup

Add the following to your `WORKSPACE` file:

```python
load("@bazel_tools//tools/build_defs/repo:java.bzl", "java_import_external")
```

### Best Practices

#### Downloading

The recommended best practices for downloading Maven jars are as follows:

1. Always follow release versions or pinned revisions.
2. Permanently mirror all dependencies to GCS or S3 as the first URL
3. Put the original URL in the GCS or S3 object name
4. Make the second URL the original repo1.maven.org URL
5. Make the third URL the maven.ibiblio.org mirror, if it isn't 404
6. Always specify the sha256 checksum

Bazel has one of the most sophisticated systems for downloading files of any
build system. Following these best practices will ensure that your codebase
takes full advantage of the level of reliability that Bazel able to offer. See
https://goo.gl/uQOE11 for more information.

#### Selection

Avoid using jars that bundle their dependencies. For example, a Maven jar for
the artifact com.initech:tps:1.0 should not contain a classes named
com.fakecorp.foo. Try to see if Initech distributes a tps jar that doesn't
bundle its dependencies. Then create a separate java_import_external() for each
one and have the first depend on the second.

Sometimes jars are distributed with their dependencies shaded. What this means
is that com.initech.tps will contain classes like
com.initech.tps.shade.com.fakecorp.foo. This is less problematic, since it
won't lead to mysterious classpath conflicts. But it can lead to inefficient
use of space and make the license of the the end product more difficult to
determine.

#### Licensing

The following values for the licenses field are typically used. If a jar
contains multiple works with difference licenses, then only the most
restrictive one is listed, and the rest are noted in accompanying comments.

The following are examples of how licenses could be categorized, ordered
by those with terms most permissive to least:

- **unencumbered**: CC0, Unlicense
- **permissive**: Beerware
- **notice**: Apache, MIT, X11, BSD, ISC, ZPL, Unicode, JSON, Artistic
- **reciprocal**: MPL, CPL, EPL, Eclipse, APSL, IBMPL, CDDL
- **restricted**: GPL, LGPL, OSL, Sleepycat, QTPL, Java, QMail, NPL
- **by_exception_only**: AGPL, WTFPL

### Naming

Bazel repository names must match the following pattern: `[_0-9A-Za-z]+`. To
choose an appropriate name based on a Maven group and artifact ID, we recommend
an algorithm https://gist.github.com/jart/41bfd977b913c2301627162f1c038e55 which
can be best explained by the following examples:

- com.google.guava:guava becomes com_google_guava
- commons-logging:commons-logging becomes commons_logging
- junit:junit becomes junit

Adopting this naming convention will help maximize the chances that your
codebase will be able to successfully interoperate with other Bazel codebases
using Java.

### Example

Here is an example of a best practice definition of Google's Guava library:

```python
java_import_external(
    name = "com_google_guava",
    licenses = ["notice"],  # Apache 2.0
    jar_urls = [
        "http://bazel-mirror.storage.googleapis.com/repo1.maven.org/maven2/com/google/guava/guava/20.0/guava-20.0.jar",
        "http://repo1.maven.org/maven2/com/google/guava/guava/20.0/guava-20.0.jar",
        "http://maven.ibiblio.org/maven2/com/google/guava/guava/20.0/guava-20.0.jar",
    ],
    jar_sha256 = "36a666e3b71ae7f0f0dca23654b67e086e6c93d192f60ba5dfd5519db6c288c8",
    deps = [
        "@com_google_code_findbugs_jsr305",
        "@com_google_errorprone_error_prone_annotations",
    ],
)

java_import_external(
    name = "com_google_code_findbugs_jsr305",
    licenses = ["notice"],  # BSD 3-clause
    jar_urls = [
        "http://bazel-mirror.storage.googleapis.com/repo1.maven.org/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar",
        "http://repo1.maven.org/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar",
        "http://maven.ibiblio.org/maven2/com/google/code/findbugs/jsr305/1.3.9/jsr305-1.3.9.jar",
    ],
    jar_sha256 = "905721a0eea90a81534abb7ee6ef4ea2e5e645fa1def0a5cd88402df1b46c9ed",
)

java_import_external(
    name = "com_google_errorprone_error_prone_annotations",
    licenses = ["notice"],  # Apache 2.0
    jar_sha256 = "e7749ffdf03fb8ebe08a727ea205acb301c8791da837fee211b99b04f9d79c46",
    jar_urls = [
        "http://bazel-mirror.storage.googleapis.com/repo1.maven.org/maven2/com/google/errorprone/error_prone_annotations/2.0.15/error_prone_annotations-2.0.15.jar",
        "http://maven.ibiblio.org/maven2/com/google/errorprone/error_prone_annotations/2.0.15/error_prone_annotations-2.0.15.jar",
        "http://repo1.maven.org/maven2/com/google/errorprone/error_prone_annotations/2.0.15/error_prone_annotations-2.0.15.jar",
    ],
)
```

### Annotation Processors

Defining jars that contain annotation processors requires a certain level of
trickery, which is best done by copying and pasting from codebases that have
already done it before. Please see the Google Nomulus and Bazel Closure Rules
codebases for examples in which java_import_external has been used to define
Dagger 2.0, AutoValue, and AutoFactory.

Please note that certain care needs to be taken into consideration regarding
whether or not these annotation processors generate actual API, or simply
generate code that implements them. See the Bazel documentation for further
information.

### Test Dependencies

It is strongly recommended that the `testonly_` attribute be specified on
libraries that are intended for testing purposes. This is passed along to the
generated `java_library` rule in order to ensure that test code remains
disjoint from production code.

### Provided Dependencies

The feature in Bazel most analagous to Maven's provided scope is the neverlink
attribute. This should be used in rare circumstances when a distributed jar
will be loaded into a runtime environment where certain dependencies can be
reasonably expected to already be provided.
"""

_HEADER = "# DO NOT EDIT: generated by java_import_external()"

_PASS_PROPS = (
    "neverlink",
    "testonly_",
    "visibility",
    "exports",
    "runtime_deps",
    "deps",
    "tags",
)

def _java_import_external(repository_ctx):
  """Implementation of `java_import_external` rule."""
  if (repository_ctx.attr.generated_linkable_rule_name and
      not repository_ctx.attr.neverlink):
    fail("Only use generated_linkable_rule_name if neverlink is set")
  name = repository_ctx.attr.generated_rule_name or repository_ctx.name
  urls = repository_ctx.attr.jar_urls
  sha = repository_ctx.attr.jar_sha256
  path = repository_ctx.name + ".jar"
  for url in urls:
    if url.endswith(".jar"):
      path = url[url.rindex("/") + 1:]
      break
  srcurls = repository_ctx.attr.srcjar_urls
  srcsha = repository_ctx.attr.srcjar_sha256
  srcpath = repository_ctx.name + "-src.jar" if srcurls else ""
  for url in srcurls:
    if url.endswith(".jar"):
      srcpath = url[url.rindex("/") + 1:].replace("-sources.jar", "-src.jar")
      break
  lines = [_HEADER, ""]
  if repository_ctx.attr.default_visibility:
    lines.append("package(default_visibility = %s)" % (
        repository_ctx.attr.default_visibility))
    lines.append("")
  lines.append("licenses(%s)" % repr(repository_ctx.attr.licenses))
  lines.append("")
  lines.extend(_make_java_import(
      name, path, srcpath, repository_ctx.attr, _PASS_PROPS))
  if (repository_ctx.attr.neverlink and
      repository_ctx.attr.generated_linkable_rule_name):
    lines.extend(_make_java_import(
        repository_ctx.attr.generated_linkable_rule_name,
        path,
        srcpath,
        repository_ctx.attr,
        [p for p in _PASS_PROPS if p != "neverlink"]))
  extra = repository_ctx.attr.extra_build_file_content
  if extra:
    lines.append(extra)
    if not extra.endswith("\n"):
      lines.append("")
  repository_ctx.download(urls, path, sha)
  if srcurls:
    repository_ctx.download(srcurls, srcpath, srcsha)
  repository_ctx.file("BUILD", "\n".join(lines))
  repository_ctx.file("jar/BUILD", "\n".join([
      _HEADER,
      "",
      "package(default_visibility = %r)" % (
          repository_ctx.attr.visibility or
          repository_ctx.attr.default_visibility),
      "",
      "alias(",
      "    name = \"jar\",",
      "    actual = \"@%s\"," % repository_ctx.name,
      ")",
      "",
  ]))

def _make_java_import(name, path, srcpath, attrs, props):
  lines = [
      "java_import(",
      "    name = %s," % repr(name),
      "    jars = [%s]," % repr(path),
  ]
  if srcpath:
    lines.append("    srcjar = %s," % repr(srcpath))
  for prop in props:
    value = getattr(attrs, prop, None)
    if value:
      if prop.endswith("_"):
        prop = prop[:-1]
      lines.append("    %s = %s," % (prop, repr(value)))
  lines.append(")")
  lines.append("")
  return lines

java_import_external = repository_rule(
    implementation=_java_import_external,
    attrs={
        "licenses": attr.string_list(mandatory=True, allow_empty=False),
        "jar_urls": attr.string_list(mandatory=True, allow_empty=False),
        "jar_sha256": attr.string(mandatory=True),
        "srcjar_urls": attr.string_list(),
        "srcjar_sha256": attr.string(),
        "deps": attr.string_list(),
        "runtime_deps": attr.string_list(),
        "testonly_": attr.bool(),
        "exports": attr.string_list(),
        "neverlink": attr.bool(),
        "generated_rule_name": attr.string(),
        "generated_linkable_rule_name": attr.string(),
        "default_visibility": attr.string_list(default=["//visibility:public"]),
        "extra_build_file_content": attr.string(),
    })
