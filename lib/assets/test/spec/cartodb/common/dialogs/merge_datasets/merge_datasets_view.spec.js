var $ = require('jquery');
var MergeDatasetsView = require('../../../../../../javascripts/cartodb/common/dialogs/merge_datasets/merge_datasets_view');

describe('common/dialog/merge_datasets/merge_datasets_view', function() {
  beforeEach(function() {
    this.table = TestUtil.createTable('a');
    this.user = new cdb.admin.User({
      base_url: 'http://pepe.cartodb.com'
    });
    this.view = new MergeDatasetsView({
      table: this.table,
      user: this.user
    });
    this.view.render();
  });

  it('should display start view', function() {
    expect(this.innerHTML()).toContain('js-flavors');
    expect(this.innerHTML()).not.toContain('js-details');
  });

  describe('when a column merge is clicked', function() {
    beforeEach(function() {
      this.firstFlavor = this.view.model.get('mergeFlavors').at(0);
      spyOn(this.firstFlavor, 'firstStep').and.callThrough();
      $(this.view.$('.OptionCard')[0]).click();
    });

    it('should render the next view', function() {
      expect(this.firstFlavor.firstStep).toHaveBeenCalled();
      expect(this.innerHTML()).not.toContain('js-flavors');
      expect(this.innerHTML()).toContain('js-details');
    });

    describe('when click back', function() {
      beforeEach(function() {
        this.view.$('.js-back').click();
      });

      it('should display start view again', function() {
        expect(this.innerHTML()).toContain('js-flavors');
        expect(this.innerHTML()).not.toContain('js-details');
      });
    });

    it('should disable next button', function() {
      var $next = this.view.$('.js-next');
      expect($next.hasClass('is-disabled')).toBeTruthy();
      spyOn(this.view, '_onNextClick');
      $next.click();
      expect(this.view._onNextClick).not.toHaveBeenCalled();
    });

    describe('when current step is ready for next step', function() {
      beforeEach(function() {
        this.view.model.get('currentStep').set('isReadyForNextStep', true);
        spyOn(this.view.model, 'gotoNextStep');
        this.view.$('.js-next').click();
      });

      it('should enable next button', function() {
        expect(this.view.$('.js-next').hasClass('is-disabled')).toBeFalsy();
      });

      it('should go to next step', function() {
        expect(this.view.model.gotoNextStep).toHaveBeenCalled();
      });
    });

    describe('current step notifies to go directly to next step', function() {
      beforeEach(function() {
        spyOn(this.view.model, 'gotoNextStep');
        this.view.model.get('currentStep').set('goDirectlyToNextStep', true);
      });

      it('should go to next step', function() {
        expect(this.view.model.gotoNextStep).toHaveBeenCalled();
      });
    });

    describe('when change current step', function() {
      beforeEach(function() {
        var fakeView = new cdb.core.View();
        fakeView.render = function() {
          this.$el.html('new step');
          return this;
        };
        this.newStep = new cdb.core.Model({});
        this.newStep.reset = jasmine.createSpy('reset');
        this.newStep.createView = jasmine.createSpy('createView').and.returnValue(fakeView);

        this.prevStep = this.view.model.get('currentStep');
        spyOn(this.prevStep, 'unbind').and.callThrough();

        this.view.model.set('currentStep', this.newStep);
      });

      it('should render the new view', function() {
        expect(this.innerHTML()).toContain('<div>new step</div>');
      });

      it('should reset state on model (in case of stepping back)', function() {
        expect(this.newStep.reset).toHaveBeenCalled();
      });

      it('should create a new view based on new step', function() {
        expect(this.newStep.createView).toHaveBeenCalled();
      });

      it('should clean up old model', function() {
        expect(this.prevStep.unbind).toHaveBeenCalled();
      });

      it('should not have leaks', function() {
        expect(this.view).toHaveNoLeaks();
      });
    });

    describe('when change current step and new step has skipDefaultTemplate set to true', function() {
      beforeEach(function() {
        var fakeView = new cdb.core.View();
        fakeView.render = function() {
          this.$el.html('new step');
          return this;
        };
        this.newStep = new cdb.core.Model({
          skipDefaultTemplate: true
        });
        this.newStep.reset = jasmine.createSpy('reset');
        this.newStep.createView = jasmine.createSpy('createView').and.returnValue(fakeView);
        this.view.model.set('currentStep', this.newStep);
      });

      it('should replace dialog content completely with new step content', function() {
        expect(this.view.$('.content').html()).toEqual('<div>new step</div>');
      });
    });
  });

  it('should not have leaks', function() {
    expect(this.view).toHaveNoLeaks();
  });

  afterEach(function() {
    this.view.clean();
  });
});
