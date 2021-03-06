
describe('cdb.admin.PrivacyDialog', function() {

  var view, organization, user, permission, model;
  beforeEach(function() {
    permission = new cdb.admin.Permission({
      owner: {
        id: 'owner_uuid'
      }
    });
    organization = new cdb.admin.Organization();
    model = new cdb.admin.Visualization({ privacy: 'PUBLIC', table: { id: 1 } });
    model.related_tables = new Backbone.Collection();
    model.permission = permission;
    user = new cdb.admin.User({ username: 'test', actions: { private_tables: false }, organization: organization });

    view = new cdb.admin.PrivacyDialog({
      model:  model,
      config: {},
      user:   user
    });
  });

  it("should render properly the dialog without organization list", function() {
    user.organization = null;
    view.render();
    expect(view.org_list).not.toBeDefined();
  });

  it("should render properly the dialog with organization list", function() {
    user.organization = organization;
    view.render();
    expect(view.org_list).toBeDefined();
  });

  it("should toggle views when visualization privacy changes", function() {
    user.organization = organization;
    user.set('actions', { private_tables: true });
    view.render();
    
    spyOn(view.org_list, 'hide');
    spyOn(view.org_list, 'show');
    spyOn(view.privacy_password, 'hide');
    spyOn(view.privacy_password, 'show');


    view.vis_model.set('privacy', 'PRIVATE');
    expect(view.org_list.show).toHaveBeenCalled();
    expect(view.privacy_password.hide).toHaveBeenCalled();

    view.vis_model.set('privacy', 'LINK');
    expect(view.org_list.show).toHaveBeenCalled();
    expect(view.privacy_password.hide).toHaveBeenCalled();

    view.vis_model.set('privacy', 'PASSWORD');
    expect(view.org_list.show).toHaveBeenCalled();
    expect(view.privacy_password.show).toHaveBeenCalled();

    // view.vis_model.set('privacy', 'ORGANIZATION');
    // expect(view.org_list.show).toHaveBeenCalled();
    // expect(view.privacy_password.hide).toHaveBeenCalled();

    view.vis_model.set('privacy', 'PUBLIC');
    expect(view.org_list.show).toHaveBeenCalled();
    expect(view.privacy_password.hide).toHaveBeenCalled();
  });

  it("should generate a copy of visualization and permissions", function() {
    user.set('organization', organization);
    view.render();
    
    expect(view.vis_model).toBeDefined();
    expect(view.vis_model.get('privacy')).toBe(model.get('privacy'));
    expect(view.vis_perm).toBeDefined();
    expect(view.vis_perm.get('acl')).toBe(permission.get('acl'));
  });

  it("should not empty acl from vis permission if visualization privacy changes to PRIVATE", function() {
    user.set('organization', organization);
    user.organization = organization
    view.render();

    var u1 = new cdb.admin.User({ username: 'test' });
    view.vis_perm.setPermission(u1, 'r');
    expect(view.vis_perm.acl.size()).toBe(1);
    view.vis_model.set('privacy', 'PRIVATE');
    expect(view.vis_perm.acl.size()).toBe(1)
  });

  it("should unset password attribute if privacy changes to any other state", function() {
    user.set('organization', organization);
    view.render();
    view.vis_model.set('password', 'jar');
    view.vis_model.set('privacy', 'PRIVATE');
    expect(view.vis_model.get('password')).toBe(undefined);
  });

  it("should not save password attribute if it is the default one", function() {
    var attributes;
    view.model.save = function(attrs, opts) {
      attributes = attrs;
    };
    view.render();
    view.vis_model.set('privacy', 'PASSWORD');
    view.vis_model.set('password', view._DEFAULT_PASSWORD);
    view._saveModels();
    expect(attributes.password).not.toBeDefined()
  });

  it("should not save the privacy change if the password is blank", function() {
    spyOn(view,'_savePrivacy');
    view.render();
    view.vis_model.set('privacy', 'PASSWORD');
    view.vis_model.set('password', '');
    view._checkPrivacy();
    expect(view._savePrivacy).not.toHaveBeenCalled();
  });

  it("should set changes in original models when save settings", function() {
    user.organization = organization;
    user.set('actions', { private_tables: true });
    view.render();

    spyOn(view.model, 'save').and.callFake(function(attr, opts) {
      opts.success();
    })
    spyOn(view.model.permission, 'save');

    view.vis_model.set('privacy', 'LINK');
    var u1 = new cdb.admin.User({ username: 'test' });
    view.vis_perm.setPermission(u1, 'r');

    view._savePrivacy();

    expect(view.model.permission.acl.size()).toBe(1);
    expect(view.model.permission.save).toHaveBeenCalled();
  });

});
