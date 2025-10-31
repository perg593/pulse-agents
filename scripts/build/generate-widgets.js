#!/usr/bin/env node
/*
 * Generates preview widget HTML from the pi-master runtime so the snippets
 * mirror the production widget output (including inline <style class="survey-..."> tags).
 *
 * Prerequisites:
 *   - Run `npm install` inside ./pi-master (already committed in this repo)
 *
 * Usage:
 *   node scripts/generate-preview-widgets.js
 */

const path = require('path');
const fs = require('fs');

const repoRoot = path.resolve(__dirname, '../..');
const piMasterRoot = path.join(repoRoot, 'pi-master');

process.chdir(piMasterRoot);
process.env.NODE_ENV = 'test';

// Bootstrap Babel + CoffeeScript
require(path.join(piMasterRoot, 'node_modules', '@babel/register'))({
  extensions: ['.js', '.jsx', '.ts', '.tsx'],
  cache: false,
});
require(path.join(piMasterRoot, 'node_modules', 'coffeescript', 'register'));

const {JSDOM} = require(path.join(piMasterRoot, 'node_modules', 'jsdom'));

const dom = new JSDOM('<!doctype html><html><body></body></html>', {
  url: 'https://preview.local',
  pretendToBeVisual: true,
});

const win = dom.window;
const assignGlobal = (name, value) =>
  Object.defineProperty(global, name, {
    value,
    configurable: true,
    writable: true,
  });

assignGlobal('window', win);
assignGlobal('document', win.document);
assignGlobal('navigator', win.navigator);
assignGlobal('location', win.location);
assignGlobal('history', win.history);
assignGlobal('HTMLElement', win.HTMLElement);
assignGlobal('Element', win.Element);
assignGlobal('Node', win.Node);
assignGlobal('CustomEvent', win.CustomEvent);
assignGlobal('MutationObserver', win.MutationObserver);
assignGlobal('DOMParser', win.DOMParser);
assignGlobal('performance', win.performance);
assignGlobal(
  'requestAnimationFrame',
  win.requestAnimationFrame.bind(win),
);
assignGlobal(
  'cancelAnimationFrame',
  win.cancelAnimationFrame.bind(win),
);
assignGlobal('getComputedStyle', win.getComputedStyle.bind(win));
assignGlobal('localStorage', win.localStorage);
assignGlobal('sessionStorage', win.sessionStorage);
assignGlobal('event', undefined);
const IntersectionObserverPolyfill = require(
  path.join(piMasterRoot, 'node_modules', 'intersection-observer'),
);
if (!win.IntersectionObserver && typeof IntersectionObserverPolyfill === 'function') {
  win.IntersectionObserver = IntersectionObserverPolyfill;
  if (global.IntersectionObserverEntry) {
    win.IntersectionObserverEntry = global.IntersectionObserverEntry;
  }
}
assignGlobal('IntersectionObserver', win.IntersectionObserver);
if (win.IntersectionObserverEntry) {
  assignGlobal('IntersectionObserverEntry', win.IntersectionObserverEntry);
}

if (!win.matchMedia) {
  win.matchMedia = () => ({
    matches: false,
    addListener() {},
    removeListener() {},
  });
}

const requireFromPi = (relativePath) =>
  require(path.join(piMasterRoot, relativePath));

// Core runtime
requireFromPi('app/assets/javascripts/surveys/mixins.coffee');
requireFromPi('app/assets/javascripts/surveys/main.coffee');
requireFromPi('app/assets/javascripts/surveys/survey.coffee');
requireFromPi('app/assets/javascripts/surveys/single_page_app.coffee');
requireFromPi('app/assets/javascripts/surveys/callback.coffee');
const DOMPurifyLib = requireFromPi(
  'vendor/assets/javascripts/patched_purify.min.js',
);
const DOMPurify =
  DOMPurifyLib || win.DOMPurify || global.DOMPurify || (() => {});
assignGlobal('DOMPurify', DOMPurify);
win.DOMPurify = DOMPurify;
requireFromPi('app/assets/javascripts/surveys/storage/local_storage.coffee');
requireFromPi('app/assets/javascripts/surveys/storage/cookies.coffee');
requireFromPi('app/assets/javascripts/surveys/storage/pageview_count.coffee');
requireFromPi('app/assets/javascripts/surveys/storage/visit_track.coffee');
requireFromPi('app/assets/javascripts/surveys/storage/visit_count.coffee');
requireFromPi('app/assets/javascripts/surveys/visitor_tracking.coffee');
requireFromPi('app/assets/javascripts/surveys/command_queue.coffee');
requireFromPi('app/assets/javascripts/surveys/text_formatting.coffee');
requireFromPi('app/assets/javascripts/surveys/debounce.js');
requireFromPi('app/assets/javascripts/surveys/render.coffee');
requireFromPi('app/assets/javascripts/surveys/free_text_question.coffee');
requireFromPi('app/assets/javascripts/surveys/multiple_choice_question.coffee');
requireFromPi('app/assets/javascripts/surveys/single_choice_question.coffee');
requireFromPi('app/assets/javascripts/surveys/slider_question.coffee');
requireFromPi('app/assets/javascripts/surveys/device_type.coffee');
requireFromPi('app/assets/javascripts/surveys/bar_survey.coffee');
requireFromPi('app/assets/javascripts/surveys/docked_widget_survey.coffee');
requireFromPi('app/assets/javascripts/surveys/inline_survey.coffee');
requireFromPi('app/assets/javascripts/surveys/top_bar_survey.coffee');
requireFromPi('app/assets/javascripts/surveys/bottom_bar_survey.coffee');
requireFromPi('app/assets/javascripts/surveys/fullscreen_survey.coffee');
requireFromPi('app/assets/javascripts/surveys/intersection_observer.coffee');

const mirrorWindowClass = (name) => {
  if (win[name]) {
    assignGlobal(name, win[name]);
  }
};
['DockedWidgetSurvey', 'InlineSurvey', 'TopBarSurvey', 'BottomBarSurvey', 'FullscreenSurvey', 'BarSurvey'].forEach(
  mirrorWindowClass,
);

requireFromPi('app/assets/javascripts/surveys.js');
assignGlobal('PulseInsightsInclude', win.PulseInsightsInclude);
assignGlobal('PulseInsightsObject', win.PulseInsightsObject);
assignGlobal('PulseInsights', win.PulseInsights);
requireFromPi('app/assets/javascripts/surveys/pulse_insights_library.js');
requireFromPi('app/assets/javascripts/surveys/get.coffee');
requireFromPi('app/assets/javascripts/surveys/jsonp.coffee');
requireFromPi('app/assets/javascripts/surveys/pdf_results.coffee');

const {
  singleChoiceQuestionFactory,
} = requireFromPi('spec/widget_unit_tests/factories/single_choice_question.js');
const {
  multipleChoiceQuestionFactory,
} = requireFromPi('spec/widget_unit_tests/factories/multiple_choice_question.js');
const {
  freeTextQuestionFactory,
} = requireFromPi('spec/widget_unit_tests/factories/free_text_question.js');
const {
  possibleAnswerFactory,
} = requireFromPi('spec/widget_unit_tests/factories/possible_answer.js');

const MOBILE_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 15_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Mobile/15E148 Safari/604.1';
const DESKTOP_UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

const THEME_PLACEHOLDER = '/* CLIENT_THEME_CSS */';
const SURVEY_OVERRIDE_PLACEHOLDER = '/* SURVEY_OVERRIDE_CSS */';

const widgetFamilies = [
  {dir: 'docked_widget', surveyType: 0},
  {dir: 'docked_widget_mobile', surveyType: 0, mobile: true},
  {dir: 'inline', surveyType: 1},
  {dir: 'inline_mobile', surveyType: 1, mobile: true},
  {dir: 'top_bar', surveyType: 2},
  {dir: 'top_bar_mobile', surveyType: 2, mobile: true},
  {dir: 'bottom_bar', surveyType: 3},
  {dir: 'bottom_bar_mobile', surveyType: 3, mobile: true},
  {dir: 'overlay', surveyType: 4},
  {dir: 'overlay_mobile', surveyType: 4, mobile: true},
];

const buildScaleData = (count, prefix) => ({
  before_answers_count: String(count),
  before_answers_items: JSON.stringify(
    Array.from({length: count}, (_, i) => `${prefix} ${i + 1}`),
  ),
  after_answers_count: String(count),
  after_answers_items: JSON.stringify(
    Array.from({length: count}, (_, i) => `${prefix.toLowerCase()} ${i + 1}`),
  ),
});

const baseSingleChoiceQuestion = () => {
  const question = singleChoiceQuestionFactory.build();
  question.content = "What's your biggest CX Challenge?";
  question.before_question_text = 'Above Question Text';
  question.after_question_text = 'Below Question Text';
  Object.assign(question, buildScaleData(2, 'Above answers'));
  question.possible_answers = possibleAnswerFactory.buildList(5).map(
    (answer, index) => ({
      ...answer,
      content: `Answer ${index + 1}`,
      position: index,
    }),
  );
  return question;
};

const scenarioDefinitions = [
  {
    file: 'single_choice_standard_buttons.html',
    createQuestions: () => {
      const question = baseSingleChoiceQuestion();
      question.button_type = 1; // standard buttons
      question.desktop_width_type = 0;
      question.answers_alignment_desktop = 2;
      return [question];
    },
  },
  {
    file: 'single_choice_radio_buttons.html',
    createQuestions: () => {
      const question = baseSingleChoiceQuestion();
      question.button_type = 0;
      return [question];
    },
  },
  {
    file: 'single_choice_dropdown_menu.html',
    createQuestions: () => {
      const question = baseSingleChoiceQuestion();
      question.button_type = 2;
      return [question];
    },
  },
  {
    file: 'multiple_choice.html',
    createQuestions: () => {
      const question = multipleChoiceQuestionFactory.build();
      question.content = 'Pick the themes that resonate.';
      question.possible_answers = possibleAnswerFactory.buildList(4).map(
        (answer, index) => ({
          ...answer,
          content: `Selection ${index + 1}`,
          position: index,
        }),
      );
      return [question];
    },
  },
  {
    file: 'free_text_single_line.html',
    createQuestions: () => {
      const question = freeTextQuestionFactory.build({
        height: 1,
        hint_text: '200 characters max',
      });
      question.content = 'Add a short note';
      return [question];
    },
  },
  {
    file: 'free_text_multiple_lines.html',
    createQuestions: () => {
      const question = freeTextQuestionFactory.build({
        height: 4,
        hint_text: 'Share as much detail as you like.',
      });
      question.content = 'Tell us more about your challenge';
      return [question];
    },
  },
  {
    file: 'custom_content.html',
    createQuestions: () => [
      {
        id: 501,
        position: 0,
        question_type: 'custom_content_question',
        content:
          '<div class="_pi_question_custom_content_question"><h2>Custom Content</h2><p>This block is rendered directly from rich text.</p><p><a href="https://www.pulseinsights.com" target="_blank">Learn more</a></p></div>',
        before_question_text: '',
        after_question_text: '',
        before_answers_count: '0',
        after_answers_count: '0',
      },
    ],
  },
  {
    file: 'thank_you.html',
    createQuestions: () => {
      const question = baseSingleChoiceQuestion();
      question.button_type = 1;
      return [question];
    },
    afterRender: () => {
      const survey = window.PulseInsightsObject.survey;
      const originalTearDown = survey.tearDownWidget.bind(survey);
      survey.tearDownWidget = () => {};
      survey.renderThankYou();
      survey.tearDownWidget = originalTearDown;
    },
  },
];

const waitForSurveyContainer = async () => {
  for (let i = 0; i < 120; i++) {
    if (document.getElementById('_pi_surveyWidgetContainer')) return;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('Timed out waiting for survey render');
};

const waitForQuestionMarkup = async (predicate) => {
  for (let i = 0; i < 120; i++) {
    if (predicate()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('Timed out waiting for widget content');
};

const resetEnvironment = () => {
  if (window.PulseInsightsObject?.survey) {
    try {
      window.PulseInsightsObject.survey.destroy();
    } catch (err) {
      // Ignore teardown errors
    }
  }

  document.body.innerHTML = '';
  Array.from(document.querySelectorAll('style[class^="survey-"]')).forEach(
    (style) => style.remove(),
  );
};

const applyMobileOverrides = (isMobile) => {
  if (isMobile) {
    navigator.userAgent = MOBILE_UA;
    window.PulseInsightsObject.isMobile = () => true;
  } else {
    navigator.userAgent = DESKTOP_UA;
    window.PulseInsightsObject.isMobile = () => false;
  }
};

const renderScenario = async (family, scenario, idSeed) => {
  resetEnvironment();
  applyMobileOverrides(!!family.mobile);

  const questions = scenario.createQuestions().map((question, index) => ({
    ...question,
    id: question.id ?? idSeed + index,
    position: index,
    possible_answers: question.possible_answers?.map((answer, answerIndex) => ({
      ...answer,
      id: answer.id ?? idSeed * 100 + answerIndex + 1,
      position: answer.position ?? answerIndex,
    })),
  }));

  const surveyAttributes = {
    id: idSeed,
    survey_type: family.surveyType,
    inline_target_position: '0',
    inline_target_selector: family.surveyType === 1 ? 'body' : undefined,
    pusher_enabled: family.dir.startsWith('top_bar') ? 'false' : undefined,
    width: 0,
    top_position: '',
    bottom_position: '',
    left_position: '',
    right_position: '10%',
    survey_locale_group_id: 'preview-locale-group',
    background_color: '#181818',
    text_color: '#ffffff',
    answer_text_color: '#ffffff',
    border_color: '#444444',
    invitation_button_disabled: 't',
    pulse_insights_branding: 't',
    display_all_questions: 'f',
    questions,
    theme_css: THEME_PLACEHOLDER,
    custom_css: SURVEY_OVERRIDE_PLACEHOLDER,
  };

  window.PulseInsightsObject.renderSurvey(surveyAttributes);
  await waitForSurveyContainer();
  await waitForQuestionMarkup(() => {
    const container = document.querySelector('._pi_widgetContentContainer');
    return (
      !!document.querySelector('._pi_question') ||
      !!container?.childElementCount
    );
  });

  if (scenario.afterRender) {
    scenario.afterRender();
    await waitForQuestionMarkup(
      () => !!document.querySelector('._pi_thankYouSurvey'),
    );
  }

  // Allow any animation timers (e.g., max-height expansion) to run
  await new Promise((resolve) => setTimeout(resolve, 50));

  const styleTags = Array.from(
    document.querySelectorAll('style[class^="survey-"]'),
  ).map((styleEl) => styleEl.outerHTML);

  const widgetContainer =
    document.getElementById('_pi_surveyWidgetContainer');

  if (!widgetContainer) {
    throw new Error('Rendered survey missing #_pi_surveyWidgetContainer');
  }

  const scriptTag = '<script src="../theme-loader.js"></script>';
  const content = `${styleTags.join('\n')}\n${widgetContainer.outerHTML}\n${scriptTag}\n`;
  return content;
};

const writeScenarioOutput = (family, scenario, html) => {
  const targetDir = path.join(
    repoRoot,
    'preview',
    'widgets',
    family.dir,
  );
  fs.mkdirSync(targetDir, {recursive: true});
  const targetFile = path.join(targetDir, scenario.file);
  fs.writeFileSync(targetFile, html, 'utf8');
};

const run = async () => {
  let idCounter = 8000;
  const results = [];

  for (const family of widgetFamilies) {
    for (const scenario of scenarioDefinitions) {
      try {
        const html = await renderScenario(family, scenario, idCounter);
        writeScenarioOutput(family, scenario, html);
        results.push({
          file: path.join(family.dir, scenario.file),
          status: 'ok',
        });
      } catch (error) {
        results.push({
          file: path.join(family.dir, scenario.file),
          status: 'error',
          message: error.message,
        });
        console.error(
          `Failed to render ${family.dir}/${scenario.file}: ${error.message}`,
        );
      }
      idCounter += 1;
    }
  }

  resetEnvironment();

  const errors = results.filter((r) => r.status === 'error');
  if (errors.length) {
    console.error(
      `Completed with ${errors.length} errors. Check the log messages above.`,
    );
    process.exit(1);
  } else {
    console.log(
      `Generated ${results.length} widget snapshots into preview/widgets/.`,
    );
  }
};

run();
