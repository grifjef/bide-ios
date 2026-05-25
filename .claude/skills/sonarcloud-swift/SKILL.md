---
name: sonarcloud-swift
description: SonarCloud setup and coverage handling for Swift/Xcode projects. Use when configuring or troubleshooting the SonarCloud analysis pipeline, converting Xcode coverage data, or interpreting Sonar findings on Swift code.
---

# sonarcloud-swift

SonarCloud configuration for Bide. Org: `grifjef`. Project: `grifjef_bide-ios`.

## One-time setup (per project)

1. Sign in at https://sonarcloud.io with the GitHub OAuth flow (already configured for `grifjef`).
2. **Analyze new project** → select `grifjef/bide-ios` from the import list.
3. After import: **Administration → Analysis Method → disable "Automatic Analysis"**. We run analysis via GitHub Actions for control over coverage and timing.
4. **Administration → Permissions** → make project public (matches the GitHub repo).
5. **My Account → Security → Generate Token** → name it `bide-ios-ci` → copy the token.
6. In GitHub: `grifjef/bide-ios → Settings → Secrets and variables → Actions → New repository secret`:
   - Name: `SONAR_TOKEN`
   - Value: paste the token from step 5

## Config files

### `sonar-project.properties` (at repo root)

```properties
sonar.projectKey=grifjef_bide-ios
sonar.organization=grifjef
sonar.projectName=Bide
sonar.sources=Bide
sonar.tests=BideTests,BideUITests
sonar.coverageReportPaths=sonar-coverage.xml
sonar.exclusions=**/Generated/**,**/.build/**,**/DerivedData/**,**/*.generated.swift,**/Preview Content/**,**/Assets.xcassets/**
sonar.sourceEncoding=UTF-8
sonar.swift.file.suffixes=.swift
```

### CI integration

See `.github/workflows/ci.yml`. The relevant pieces:

1. Run tests with `-enableCodeCoverage YES -resultBundlePath TestResults.xcresult`
2. Convert coverage:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/SonarSource/sonar-scanning-examples/master/swift-coverage/swift-coverage-example/xccov-to-sonarqube-generic.sh -o xccov-to-sonarqube-generic.sh
   chmod +x xccov-to-sonarqube-generic.sh
   ./xccov-to-sonarqube-generic.sh TestResults.xcresult > sonar-coverage.xml
   ```

3. Scan:

   ```yaml
   - uses: SonarSource/sonarqube-scan-action@v5
     env:
       SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
   ```

## Quality gate behavior

SonarCloud's default gate fails the build if:
- New code coverage < 80%
- New duplicated lines > 3%
- Maintainability rating worse than A
- Reliability rating worse than A
- Security rating worse than A

For initial development, the `sonarcloud` job in CI is set `continue-on-error: true`. Flip to `false` once we have a stable baseline (~Phase 3).

## Reading findings

- **Bugs** — definite or likely problems (force-unwraps, nil dereferences, missing protocol conformance)
- **Code smells** — maintainability issues (function too long, file too long, magic numbers)
- **Security hotspots** — manual review needed (any use of `withUnsafePointer`, `NSCoder` without entitlements, etc.)
- **Vulnerabilities** — confirmed security issues (rare in pure Swift; more common in mixed projects)

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `Project key X is invalid or you don't have permission` | Token bad or project not imported | Regenerate token; confirm project exists in SonarCloud UI |
| `0% coverage shown but tests ran` | `xccov-to-sonarqube-generic.sh` output empty | Verify `TestResults.xcresult` is non-empty; confirm scheme has "Code Coverage" enabled in Test action options |
| `Issues reported on file paths that don't exist` | sources path mismatch | `sonar.sources` must match the actual source directory in CI working dir |
| Scan takes >10min | Too many files / no exclusions | Add `**/Generated/**`, `**/.build/**` to `sonar.exclusions` |
| Swift analyzer not running | SonarCloud free tier limits Swift analysis on some orgs | Check project is public; Swift analysis is free for public repos |

## Local pre-push check (optional)

```bash
brew install sonar-scanner
sonar-scanner \
  -Dsonar.token=$SONAR_TOKEN \
  -Dsonar.host.url=https://sonarcloud.io
```

(Avoid running locally during normal dev — eats the CI quota. Use sparingly when investigating CI-only failures.)
