# Legacy Theme MVP Changelog

## Version 1.0.1 - 2025-10-29

### Dependencies Updated
- **BREAKING**: Updated Puppeteer from ^19.11.1 to ^24.23.0
  - This major version update includes significant API changes
  - Some deprecated methods may no longer work
  - Browser launch options have changed
  - See [Puppeteer Migration Guide](https://pptr.dev/guides/migration) for details

### Compatibility Notes
- Node.js version 18+ is now required
- Some browser automation features may behave differently
- Test thoroughly before using in production

### Migration Steps
1. Run `npm install` to update dependencies
2. Review any custom Puppeteer usage for deprecated APIs
3. Test theme generation with various websites
4. Update any custom browser launch configurations

### Known Issues
- None identified at this time

### Future Plans
- This legacy package is deprecated and will not receive active maintenance
- Use the main theme-generator package for new development
- Consider migrating custom scripts to the main theme generator
