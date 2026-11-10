ObjC.import('AppKit');

const ROW_HEIGHT = 32;
const LABEL_WIDTH = 110;
const POPUP_WIDTH = 340;
const GAP = 8;

// Each argument: "Label|current key|key:Title,key:Title". Prints chosen keys, one per line.
function run(argv) {
  const groups = argv.map((arg) => {
    const [label, current, options] = arg.split('|');
    const items = options.split(',').map((item) => {
      const [key, title] = item.split(':');
      return { key, title };
    });
    return { label, current, items };
  });

  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
  app.activateIgnoringOtherApps(true);

  const width = LABEL_WIDTH + GAP + POPUP_WIDTH;
  const view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, width, ROW_HEIGHT * groups.length));
  const popups = groups.map((group, index) => {
    const y = ROW_HEIGHT * (groups.length - 1 - index);
    const label = $.NSTextField.labelWithString(group.label);
    label.frame = $.NSMakeRect(0, y + 4, LABEL_WIDTH, 20);
    const popup = $.NSPopUpButton.alloc.initWithFramePullsDown(
      $.NSMakeRect(LABEL_WIDTH + GAP, y, POPUP_WIDTH, 26),
      false
    );
    group.items.forEach((item) => popup.addItemWithTitle(item.title));
    popup.selectItemAtIndex(Math.max(0, group.items.findIndex((item) => item.key === group.current)));
    view.addSubview(label);
    view.addSubview(popup);
    return popup;
  });

  const alert = $.NSAlert.alloc.init;
  alert.messageText = 'Tools settings';
  alert.addButtonWithTitle('Save');
  alert.addButtonWithTitle('Cancel');
  alert.accessoryView = view;
  if (alert.runModal !== $.NSAlertFirstButtonReturn) {
    return '';
  }
  return groups.map((group, index) => group.items[ObjC.unwrap(popups[index].indexOfSelectedItem)].key).join('\n');
}
